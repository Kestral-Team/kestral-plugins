---
name: kestral-sync
description: >-
  Keep Kestral in sync with your work session: task lookup, conflict detection, progress comments,
  status updates, deliverable linking, and task creation — all via the Kestral MCP. Install the
  companion rule/snippet for ambient sync (auto-triggers on milestones, reviews, or phase
  completion); invoke manually as the "sync now" escape hatch.
---

# Kestral Sync

## When to Sync

Update the Kestral task when:

- **Work progress:** milestone complete, deliverable shared (e.g. branch push, PR opened, document published), blocker
  worth documenting
- **Fixes:** issue investigated and resolved, unlinked work surfaced (e.g. unlinked branch pushed — prompt to create
  task)
- **Review:** review complete (post Review Summary — even when clean)
- **Decision:** investigation or prototype concluded (capture the proceed/pivot/kill verdict)
- **General:** user asks to sync, user asks to create a task

Do NOT update on every minor edit, routine commit, or incremental save.

**Dedup:** Before posting, call `entity_lookup` to read existing comments. If the most recent comment covers the same
work with no new progress, skip.

---

## Core Infrastructure

### Identity & Error Handling

The MCP connection is OAuth-authenticated at the transport layer — you do not need to call `whoami` to verify auth
before making calls.

**`whoami`** returns workspace and member identity (workspace ID, member ID, names). Call it when you need `memberId` —
for **Conflict Check** and when ranking multiple task lookup candidates (prefer tasks assigned to you). Cache the result
for the rest of the session — do not call again unless a prior call returned stale data.

**Auth failure signals:** HTTP 401, `unauthorized`, or tool error `Not authenticated` (MCP v2 returns
`{"error":"Not authenticated"}` via `errorResult` — the message does not contain `401`). When any Kestral MCP call
returns one of these, the OAuth token has expired or the connection dropped. Guide the user to re-authenticate through
their app's UI — the agent cannot handle OAuth directly. Cowork: Customize → Connectors; Codex: Settings → MCP Servers →
Authenticate; Claude Code: `/mcp` → reconnect; Cursor: Settings → MCP Servers → Authenticate (or agent calls
`mcp_auth`). Do not retry other tools until the user confirms reconnection.

All MCP calls require an `explanation` field — use a clear description of the operation.

### Task Lookup — Fast Lookup Chain

Find the Kestral task for the current work. Each step is 1–3 seconds except the last; stop as soon as you have a match:

1. **Slug in context:** if the user mentioned a task slug (e.g. `KES-42`) or the git branch contains one (e.g.
   `kes-42-fix-auth`), call `entity_lookup` with the slug directly — instant.
2. **Branch→task exact match (code repos only):**
   `execute_operation("find_task_by_branch", { branchName: "<current-branch>" })`. May return multiple tasks if the
   branch is shared. One match → use it. Multiple → apply **Candidate Ranking** below. Skip this step outside code
   repositories.
3. **My active tasks:** `execute_operation("list_my_active_tasks", {})` — tasks assigned to me in todo or in_progress.
   Exactly one match → use it. Multiple → apply **Candidate Ranking** (title match first among my tasks).
4. **Keyword search:**
   `execute_operation("search_my_tasks_by_keyword", { keyword: "<keywords from current work>", statusFilter: ["todo", "in_progress"] })`.
   Use keywords from your current work context (branch name, document title, topic). Scoped to my tasks — do not use
   `search_tasks` with `assigneeFilter`; that param is dropped at validation.
5. **`execute_operation("deep_research", { query })`** — **last resort only** (10–30 seconds). Frame as the user-facing
   problem.

After resolution:

- One clear match → use it
- Multiple matches → apply **Candidate Ranking** below (get `memberId` from `whoami` once per session for assignment
  comparison); if still tied, ask the user to pick
- No matches → auto-create a task (see Task Creation / Unlinked Branch Prompt); only ask the user if the project is
  ambiguous
- Hold the task ID in session context for subsequent updates

If the user provided a task URL, slug, or ID directly, skip the chain and call `entity_lookup` immediately.

#### Candidate Ranking

When any step returns multiple candidates (including `find_task_by_branch` when tasks share a branch), rank by:

1. **Title/scope match** — prefer the task whose title describes the current work over a loosely related match.
2. **Status** — prefer Todo / In Progress over Done (Done → warn, do not silently link).
3. **Assignment** — prefer tasks assigned to the current user (`assigneeId` === cached `memberId` from `whoami`) over
   unassigned, and unassigned over tasks assigned to someone else.
4. **Recency** — among equal candidates, prefer the more recently created task.

#### Status Discovery

Workspaces have custom statuses — never hardcode status keys. Call `list_statuses` to discover valid `statusKey` values
before any status update. This skill uses generic terms like "in-progress," "review," and "done" to describe workflow
stages — map them to whatever keys your workspace defines.

#### Archived Project Guard

Skip archived projects (`archivedAt` non-null) when choosing a target — the server rejects writes to them.

### Conflict Check

Before starting work or claiming a task:

1. Get `memberId` from `whoami` (once per session when first needed; reuse cached result from Candidate Ranking if
   already fetched)
2. Compare `entity.assigneeId` against `memberId`
3. **Already done:** status is Done → verify the work is actually complete before redoing
4. **No conflict:** `assigneeId` is null (and status Todo/Backlog) or matches current user
5. **Conflict:** `assigneeId` differs AND status is active (In Progress, Awaiting Review, etc.)
6. **On conflict or done:** warn user with `assigneeName`, `statusName`, and any open PRs from `prLinks`
7. Ask: **proceed** / **coordinate** / **pick a different task**

**Adjacent-work:** if lookup returns near-matches that overlap the planned scope and are active or Done, surface what's
already been done and propose a scope adjustment. Prefer creating a separate task linked with `create_task_relationship`
(`relationshipType: "related"`) over silently adopting a Done task.

### Context Pull

Before starting, pull project context so the agent knows *why* the task exists:

1. **Identify project:** task → `entity_lookup` → `projectId`. Or `execute_operation("search_projects", { query })`; ask
   if ambiguous.
2. **Pull project brain:** `execute_operation("get_project_brain", { projectId })`, or
   `entity_lookup({ id: "<projectId>", type: "project_brain" })`.
   - Check `brainGenerationStatus` in the response: if `queued` or `running`, tell the user "Brain is building (~30s)"
     instead of "no brain found."
   - If no brain exists, mention `execute_operation("trigger_brain_build", { projectId })` as an option.
3. **Pull related tasks:**
   `execute_operation("list_tasks_by_status", { statusFilter: ["todo", "in_progress"], projectId })`, or
   `execute_operation("search_tasks", { query: "<topic from task or project>" })` when a semantic topic fits better.
4. **One-call alternative:** `entity_lookup` with `{ id: taskId, type: "task" }` — returns task + brain + related in a
   single call.
5. **Pull customer feedback:** `execute_operation("search_feedback", { query })` — frame the query around the task or
   project topic to surface the user-facing *why*.
6. **Summarize** — present a brief digest; do not dump the full brain output.

**Session start option:** `execute_operation("get_daily_brief", {})` returns a personal summary of what changed across
all your projects — useful at the start of a session.

---

## Task Creation

### Project Selection

Before creating any task, resolve a `projectId`. Never guess from nearby chat topics alone.

1. **Prefer an already-linked project** when one exists (linked task, originating spike/prototype task, or confirmed
   branch task).
2. **Otherwise search:** `execute_operation("search_projects", { query })` with keywords from the **task subject and
   intended workstream** (what the work is for), not product names that only appear in adjacent conversation. If
   `sync_session_workflow` returned `context.projects`, treat that list as candidates and **re-rank** — do not pick the
   first or most salient name match.
3. **Skip archived projects** (`archivedAt` non-null).
4. **Match work type:**
   - Product / launch / build work → projects about shipping that product.
   - Customer follow-up / deal support / call routing → existing triage or customer-request buckets whose description
     matches that work type — not a product-launch project just because the follow-up mentions a product.
5. **Decide:**
   - Exactly one strong match → use it.
   - Several plausible matches → surface the top candidates (name + ID) and ask the user; do not hard-assume.
   - Unclear → prefer in order: strongest existing work-type fit → a general triage / routing bucket → ask the user.
6. **Do not create a new project** unless the user explicitly asks for one, or search shows no reasonable existing
   destination. Never create a single-customer project as a shortcut.
7. **After the user rejects a project:** re-rank the remaining existing projects for the work type. Do **not** call
   `create_project` as the recovery default.

### From Current Work

When the user wants a task for work in progress (no existing task found):

1. **Gather context:** In a code repo: `git branch --show-current`, `git log --oneline -20`,
   `git diff --stat main...HEAD`. Otherwise: summarize the current work from the conversation or documents at hand.
2. **Project:** apply **Project Selection**.
3. **Create:**
   `execute_operation("create_task", { projectId, title, description, checkDuplicates: true, source: "mcp" })` — title
   from the work topic, description as plain-language markdown (Summary, What was done, Why it matters). If blocked as a
   duplicate, present the existing task instead of creating.
4. **Register branch (code repos only):** `execute_operation("register_branch_on_task", { taskId, branchName })` —
   enables step 2 of the lookup chain for all future lookups. Skip outside code repositories.
5. **Link PR** (if one exists): `execute_operation("link_pr_to_task", { taskId, prUrl })`.
6. **Confirm:** present the task URL.

### From Bugfix

Title: `Fix: [what was broken, user-facing]`

Description:

- **What broke:** [user-visible symptom]
- **Root cause:** [1-sentence technical cause, plain language]
- **Fix:** [what was changed and why]
- **Impact:** [who was affected, severity, duration if known]
- **Related:** [link to support ticket, alert, or Slack thread if applicable]

Steps (preferred — single compound call):

1. **Project:** apply **Project Selection** (keywords from the fix context).
2. **Create + register + link:**
   `execute_operation("create_task_for_branch", { branchName, projectId, title, description, prUrl, source: "bugfix" })`.
3. **Confirm:** present the task URL from the response.

Alternative (when branch is not available or compound op unavailable):

1. **Project:** apply **Project Selection**.
2. **Create:**
   `execute_operation("create_task", { projectId, title, description, checkDuplicates: true, source: "mcp" })`.
3. **Register branch (code repos only):** `execute_operation("register_branch_on_task", { taskId, branchName })`.
4. **Link PR** (if one exists): `execute_operation("link_pr_to_task", { taskId, prUrl })`.
5. **Confirm:** present the task URL.

If the PR is already merged: create with a completed/done status (use `list_statuses` to find the right key), link PR,
skip progress comments — the task is a historical record.

### From Plan

After writing a structured plan with phases or checklists, offer to create tracking tasks. If the user declines, skip.

1. **Project:** apply **Project Selection**.
2. **Batch create:** `execute_operation("create_tasks_batch", { projectId, tasks: [...] })` with
   `duplicatePolicy: "block"` — one task per phase. `title` = phase title, `description` = checklist items as markdown
   task list, `source: "cursor-plan"`. Review any `duplicates` in the response and present them to the user.
3. **Subtasks:** Only for project-scale plans where phases are separate deliverables. For typical single-document plans,
   phase-level tasks with checklist descriptions suffice.
4. **Confirm:** Present created tasks as markdown links.

### From Prototype

Create at the start of a spike or prototype — framed as the **question being answered**, not the work being done.

Title: `[Question being de-risked]` — e.g. "Should we use SSE or WebSockets for real-time updates?"

Description:

- **Question:** [what we're trying to answer]
- **Approach:** [what we'll build/test — 1-2 sentences]
- **Timebox:** [when we commit to a direction regardless]
- **Success criteria:** [what evidence justifies proceed / pivot / kill]

Steps:

1. **Project:** apply **Project Selection** (keywords from the spike topic).
2. **Create:**
   `execute_operation("create_task", { projectId, title, description, checkDuplicates: true, source: "mcp" })`.
3. **Register branch (code repos only):** `execute_operation("register_branch_on_task", { taskId, branchName })`.
4. **Confirm:** present the task URL.

On conclusion, the decision-capture flow updates this task: retitle with the decision verb if helpful, post a **Decision
Comment**, link artifacts, and set status.

### From Decision

When a spike/prototype concluded with "proceed" and a follow-up implementation task is needed. Description must stand
alone without reading the spike history.

Title: the work to be done, user-facing framing (not "implement the decision")

Description:

```markdown
## Context

[1-2 sentences: the question we de-risked and what we decided]

**Decision:** [proceed — chosen approach] **Validated by:** [link to spike/prototype task, mockup, or POC branch]
**Trade-offs accepted:** [what we gave up, if notable]

## Scope

[What to build — from the decision rationale]

**Out of scope:** [anything explicitly deferred]
```

Steps:

1. **Project:** same project as the originating spike/prototype task when available; otherwise apply **Project
   Selection**.
2. **Create:** `execute_operation("create_task", { projectId, title, description, checkDuplicates: true, source })` —
   use `source: "cursor-plan"` if originating from a spike plan, otherwise `"mcp"`.
3. **Link the chain:** reference the originating task in the new description, and post a comment on the originating task
   (`execute_operation("add_task_comment", { taskId: originatingTaskId, content: "Follow-up implementation: [task link]" })`).
4. **Confirm:** present the task URL.

### Unlinked Branch — Auto-Create

When syncing after a push and no Kestral task is linked to the current branch, **create a task automatically** — do not
prompt the user for permission. The `create_task_for_branch` call is idempotent (`checkDuplicates: true`) and safe to
call speculatively.

1. Check if a task exists via Task Lookup (fast chain)
2. If no match: gather context (`git log`, `git diff --stat`, branch name, PR if any) and apply **Project Selection**.
3. Auto-create: prefer
   `execute_operation("create_task_for_branch", { branchName, projectId, title, description, prUrl, source })` — this
   does branch lookup, task creation, branch registration, and PR linking in one call. Fall back to **From Current
   Work** (or **From Bugfix**) when the compound operation is unavailable.
4. **Confirm:** present the task URL. Interpret the create response with this three-outcome table:

| Response signal                                           | Meaning                                                            | What to do                                                                                  |
| --------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `created: false` + Done `warning` (true duplicate/reopen) | Matched an existing Done task                                      | Ask the user: reopen/continue that task, or create new work? Do **not** silently adopt.     |
| `created: true` + `relatedTo`                             | New task created and linked as related to a near-miss (often Done) | Treat as success. Branch/PR are on the **new** task only. Mention the related task briefly. |
| `created: true` with no `relatedTo` / no Done warning     | Fresh create, unrelated                                            | Confirm the new task URL as usual.                                                          |
| Blocked as duplicate (open task)                          | High-confidence open match                                         | Present the existing task and link branch/PR to it instead of creating.                     |

If the user confirms **new work** after a Done duplicate warning (no `relatedTo`), create via **From Bugfix** or **From
Current Work** with `duplicatePolicy: "create_anyway"` and
`overrideReason: "New work, existing task was already completed"`, then optionally
`execute_operation("create_task_relationship", { fromTaskId: newTaskId, toTaskId: doneTaskId, relationshipType: "related" })`
to attach a related edge.

Use `create_task_relationship` anytime you need an ad-hoc `related` / `blocker` / `replaces` link between two existing
tasks (outside create-time `replacementForTaskId` for replaces).

**Skip auto-create when:** the work is a review-feedback fix, CI fix, small chore, or incidental commit (schema
regeneration, dep bump, lint fix) on a branch that already has a linked task.

---

## Task Updates

### Task Pickup

When the user picks up a task:

1. Task Lookup (fast chain above)
2. Conflict Check
3. **Claim:**
   - **Code repos:** derive and confirm the branch name (slug + title, lowercase hyphenated) — ask the user before
     registering it on the task or creating the git branch. Then:
     `execute_operation("claim_task_and_branch", { taskId, branchName })` — single call replaces assign + status +
     branch + comment.
   - **Non-code contexts:** mirror the same semantics without a branch:
     1. `execute_operation("update_task", { taskId, statusKey: "<in_progress_key>", assigneeId: "me" })` — assign self
        and set in-progress (use `list_statuses` to find the in-progress key if unsure).
     2. `execute_operation("add_task_comment", { taskId, content: "Started work on [slug]." })` — post the pickup
        comment.
4. **Confirm:** "Claimed [slug], set to [status name]."

### Status Update

Call `list_statuses` first, then `execute_operation("update_task", { taskId, statusKey })`. Only update at meaningful
transitions. Run the Acceptance Check before moving a task to a completed/review status.

**Completion gate:** A task's "done" or "completed" status means the work is **fully delivered** — not just finished on
your end. If a linked PR is still open/unmerged, use the workspace's review/pending status instead. When no PR applies
(non-code work, or user explicitly confirms completion), `done` is valid. Never mark a task complete while a linked PR
is unmerged.

### Acceptance Check

Before updating task status after completing work:

1. `entity_lookup` — get acceptance criteria from the task description
2. Review what was done — in a code repo: `git diff --stat main...HEAD`; otherwise: summarize the deliverables
3. For each criterion: satisfied? (Yes / No / Partial)
4. All satisfied → if a PR exists, check merge state: use the workspace's review/pending status if PR is open/unmerged;
   only use the completed/done status if the PR is merged (or no PR applies). Gaps → report, ask user.

---

## Comments

Comments are posted via `execute_operation("add_task_comment", { taskId, content })`. Format the content appropriately
for the comment type (progress update, bugfix note, review summary, decision, retrospective). Follow the writing style
rule: **conversational outcomes** ("Users can now filter by date range"), not implementation jargon ("Added
filterByDateRange param"). No file paths or function names. 2–4 lines max.

### Progress Comment

```markdown
**Progress Update**

[1–2 sentence plain-language summary of outcomes]

**Up next:** [what remains, or "Done!" if complete]
```

Add `**Blocked on:** [description]` if applicable.

### Bugfix Comment

For fixes on an **existing** task (technical content is appropriate here — exception to the style rule):

```markdown
**Bugfix**

**What broke:** [user-visible symptom] **Root cause:** [1-sentence technical cause] **Fix:** [what was changed and why]
**Evidence:** [logs, stack trace, or PR link]
```

### Decision Comment

When a spike or prototype concludes:

```markdown
**Decision: [proceed / pivot / kill]**

[1–2 sentence rationale]

**Evidence:** [link to prototype/benchmark/branch] **Next:** [follow-up task title, or "No further action"]
```

### Review Summary

Post after completing a review — **whether findings are clean or not**:

```markdown
**Review Summary**

[What the change does for users + review verdict]

**Scope:** [files/areas reviewed, PR link] **Findings:** [N critical / N medium / N low — or "Clean — no issues found"]
**Up next:** [fixes needed, or "Ready for merge"]
```

### Retrospective Comment

Post when a review or incident reveals a process gap:

```markdown
**Retrospective**

**What happened:** [the miss — what slipped through] **Why we missed it:** [root cause of the process gap] **What we
changed:** [rule/check added or updated] **Prevents:** [class of issues this catches going forward]
```

---

## Linking

### Work Linking

**Code repos — compound PR linking (preferred):**
`execute_operation("complete_task_with_review", { taskId, prUrl, summary: "PR opened: <title>" })` — links the PR, sets
status to `awaiting_review`, and posts a comment in one call.

- PR exists → `execute_operation("link_pr_to_task", { taskId, prUrl })` (auto-assigns if unassigned, posts GitHub PR
  comment)
- Branch only (no PR yet) → `execute_operation("add_task_comment", { taskId, content })`:
  `Started work on branch \`branch-name\``
- Post each link **once per session**

**Non-code contexts:** post a comment noting what was shared or delivered (e.g. a document link, design file, or
deliverable URL).

### Artifact Task References

When creating structured documents (implementation plans, design docs, spike writeups), embed the linked Kestral task ID
so future agents can reconnect to context without a lookup chain:

- **Plan frontmatter:** include `kestralTaskId` and `kestralTaskUrl` fields
- **Document headers:** include a task reference link or slug
- **PR descriptions:** include the task slug for webhook auto-link

This enables fast task lookup (step 1 of the lookup chain) and avoids repeated `find_task_by_branch` calls across
sessions.

### Draft PR Creation

When the user confirms creating a draft PR:

1. Check for existing PR: `gh pr list --head $(git branch --show-current) --json number,title,url,isDraft --limit 1`. If
   exists, use Work Linking instead.
2. Push branch if needed. If uncommitted changes remain, ask before committing.
3. `gh pr create --draft` with outcome-focused title/body. For chore/no-task PRs, include
   `<!-- kestral:skip-auto-link -->` in the body (see **GitHub PR auto-link directives**).
4. If a Kestral task is linked: `execute_operation("link_pr_to_task", { taskId, prUrl })` with the new PR URL (once per
   session). Skip when the PR uses the skip directive and has no task.
5. Return PR URL to user.

### GitHub PR auto-link directives

Code repos only. When the workspace **Auto-link & create tasks on PR open** beta is enabled, Kestral may enqueue an AI
job for PRs with no slug/branch match. Control this via the PR **body** (include when running `gh pr create` or editing
on GitHub).

| Intent                                                  | Action                                                                                                                                                                                                                                      |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Link PR to tracked work** (default)                   | `execute_operation("register_branch_on_task", { taskId, branchName })` on first push; `execute_operation("link_pr_to_task", { taskId, prUrl })` after PR exists. Optional: put task slug in PR title for webhook slug auto-link without AI. |
| **Skip AI auto-link** (chore / manifest bump / no task) | Add to PR body: `<!-- kestral:skip-auto-link -->` **or** `Kestral: skip auto-link`                                                                                                                                                          |

Suppresses AI auto-link job enqueue and transient bot comments; does **not** affect `link_pr_to_task`, slug/branch
webhook linking, or PR status automation. Use for `chore/*`, manifest bumps, and docs-only PRs without a task.

### Full Sync

Complete sync workflow (user asks to sync, or auto-trigger fires):

1. Proceed with MCP calls (OAuth at transport; stop on auth failure — 401, unauthorized, or `Not authenticated`)
2. Gather context — in a code repo: `git log --oneline -10`, `git diff --stat main...HEAD`. Otherwise: summarize recent
   work from the conversation or documents at hand.
3. Task lookup (fast chain) — `entity_lookup` also returns existing comments
4. **Dedup:** if the most recent comment covers the same scope with no new progress → skip, confirm "no updates"
5. Status update (skip if already correct; Acceptance Check before marking complete)
6. Comment — pick the format: Review Summary after a review, Decision Comment after a spike, Bugfix Comment for a fix,
   otherwise Progress Comment
7. Work linking if applicable
8. Confirm what was synced (include task URL)

---

## Complex Operations

For multi-step or multi-entity operations (bulk updates, project archiving, subtask hierarchy, tag management, task
prioritization), use `execute_operation("manage_project", { request })` with a natural-language request. It routes to an
AI agent that handles the right sequence of actions (10–30 seconds).
