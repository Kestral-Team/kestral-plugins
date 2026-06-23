---
name: kestral-sync
description: >-
  Keep Kestral in sync with your coding session: task lookup, conflict detection, progress comments,
  status updates, PR linking, and task creation — all via the Kestral MCP. Install the companion
  rule/snippet for ambient sync (auto-triggers on push, PR, phase completion); invoke manually as
  the "sync now" escape hatch.
---

# Kestral Sync

## When to Sync

Update the Kestral task when:

- **Implementation:** phase/feature complete, first branch push, PR created, blocker worth documenting
- **Retroactive:** bug investigated and fixed, unlinked branch pushed (prompt to create task)
- **Review:** code review complete (post Review Summary — even when clean)
- **Decision:** spike or prototype concluded (capture the proceed/pivot/kill verdict)
- **General:** user asks to sync, user asks to create a task for the branch

Do NOT update on every commit or minor edit.

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

1. **Slug in branch name:** if the branch contains a slug (e.g. `kes-42-fix-auth`), call `entity_lookup` with the slug
   directly — instant.
2. **Branch→task exact match:** `execute_operation("find_task_by_branch", { branchName: "<current-branch>" })`. Returns
   the task linked to this branch, if any (0 or 1 result).
3. **My active tasks:** `execute_operation("list_my_active_tasks", {})` — tasks assigned to me in todo or in_progress.
   Exactly one match → use it. Multiple → apply **Candidate Ranking** (title match first among my tasks).
4. **Keyword search:**
   `execute_operation("search_my_tasks_by_keyword", { keyword: "<branch-slug-as-words>", statusFilter: ["todo", "in_progress"] })`.
   Convert the branch slug to words (e.g. `feat/improve-auth-flow` → `"improve auth flow"`). Scoped to my tasks — do not
   use `search_tasks` with `assigneeFilter`; that param is dropped at validation.
5. **`execute_operation("deep_research", { query })`** — **last resort only** (10–30 seconds). Frame as the user-facing
   problem, include branch name.

After resolution:

- One clear match → use it
- Multiple matches → apply **Candidate Ranking** below (get `memberId` from `whoami` once per session for assignment
  comparison); if still tied, ask the user to pick
- No matches → ask the user; offer to create a task (see Task Creation)
- Hold the task ID in session context for subsequent updates

If the user provided a task URL, slug, or ID directly, skip the chain and call `entity_lookup` immediately.

#### Candidate Ranking

When multiple candidates appear (especially from `deep_research`), rank by:

1. **Title/scope match** — prefer the task whose title describes the branch/work over a loosely related match.
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

Before starting implementation or claiming a task:

1. Get `memberId` from `whoami` (once per session when first needed; reuse cached result from Candidate Ranking if
   already fetched)
2. Compare `entity.assigneeId` against `memberId`
3. **Already done:** status is Done → verify against the codebase before redoing
4. **No conflict:** `assigneeId` is null (and status Todo/Backlog) or matches current user
5. **Conflict:** `assigneeId` differs AND status is active (In Progress, Awaiting Review, etc.)
6. **On conflict or done:** warn user with `assigneeName`, `statusName`, and any open PRs from `prLinks`
7. Ask: **proceed** / **coordinate** / **pick a different task**

**Adjacent-work:** if lookup returns near-matches that overlap the planned scope and are active or Done, surface what's
already been done and propose a scope adjustment.

### Context Pull

Before building, pull project context so the agent knows *why* the task exists:

1. **Identify project:** task → `entity_lookup` → `projectId`. Or `execute_operation("search_projects", { query })`; ask
   if ambiguous.
2. **Pull project brain:** `entity_lookup({ id: "<projectId>", type: "project_brain" })`.
   - Check `brainGenerationStatus` in the response: if `queued` or `running`, tell the user "Brain is building (~30s)"
     instead of "no brain found."
   - If no brain exists, mention `execute_operation("trigger_brain_build", { projectId })` as an option.
3. **Pull related tasks:**
   `execute_operation("list_tasks_by_status", { statusFilter: ["todo", "in_progress"], projectId })`, or
   `execute_operation("search_tasks", { query: "<topic from task or project>" })` when a semantic topic fits better.
4. **One-call alternative:** `execute_operation("get_implementation_context", { taskId })` — returns task + brain +
   related in a single call.
5. **Pull customer feedback:** `execute_operation("search_feedback", { query })` — frame the query around the task or
   project topic to surface the user-facing *why*.
6. **Summarize** — present a brief digest; do not dump the full brain output.

**Session start option:** `execute_operation("get_daily_brief", {})` returns a personal summary of what changed across
all your projects — useful at the start of a session.

---

## Task Creation

### From Branch

When the user wants a task for the current branch (no existing task found):

1. **Gather context:** `git branch --show-current`, `git log --oneline -20`, `git diff --stat main...HEAD`
2. **Find project:** `execute_operation("search_projects", { query })` with branch/commit keywords; ask if ambiguous.
3. **Create:**
   `execute_operation("create_task", { projectId, title, description, checkDuplicates: true, source: "mcp" })` — title
   from branch + commits, description as plain-language markdown (Summary, What was built, Why it matters). If blocked
   as a duplicate, present the existing task instead of creating.
4. **Register branch:** `execute_operation("register_branch_on_task", { taskId, branchName })` — enables step 2 of the
   lookup chain for all future lookups.
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

If the PR is already merged: create with a completed/done status (use `list_statuses` to find the right key), link PR,
skip progress comments — the task is a historical record.

---

## Task Updates

### Task Pickup

When the user picks up a task:

1. Task Lookup (fast chain above)
2. Conflict Check
3. Derive and confirm the branch name (slug + title, lowercase hyphenated) — ask the user before registering it on the
   task or creating the git branch.
4. **Claim:** `execute_operation("claim_task_and_branch", { taskId, branchName })` — uses the confirmed name from step
   3; single call replaces assign + status + branch + comment. Returns 409 if the branch is already linked to another
   task (conflict signal).
5. **Confirm:** "Claimed [slug], set to [status name]."

### Status Update

Call `list_statuses` first, then `execute_operation("update_task_status", { taskId, statusKey })`. Only update at
meaningful transitions. Run the Acceptance Check before moving a task to a completed/review status.

**PR merge gate:** A task's "done" or "completed" status means the PR is **merged**, not just that implementation is
finished. If a linked PR is still open, use the workspace's review/pending status instead. The one exception: when no PR
exists and the user explicitly confirms the work is complete, `done` is valid. Never mark a task complete while its PR
is unmerged.

### Acceptance Check

Before updating task status after implementation:

1. `entity_lookup` — get acceptance criteria from the task description
2. `git diff --stat main...HEAD` — see what changed
3. For each criterion: satisfied? (Yes / No / Partial)
4. All satisfied → check PR merge state: use the workspace's review/pending status if PR is open/unmerged; only use the
   completed/done status if the PR is merged. Gaps → report, ask user.

---

## Comments

Comments are posted via `execute_operation("post_progress_comment", { taskId, content })` for progress updates, or
`execute_operation("add_task_comment", { taskId, content })` for other comment types. Follow the writing style rule:
**conversational outcomes** ("Users can now filter by date range"), not implementation jargon ("Added filterByDateRange
param"). No file paths or function names. 2–4 lines max.

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

Post after completing a code review — **whether findings are clean or not**:

```markdown
**Review Summary**

[What the change does for users + review verdict]

**Scope:** [files/areas reviewed, PR link] **Findings:** [N critical / N medium / N low — or "Clean — no issues found"]
**Up next:** [fixes needed, or "Ready for merge"]
```

---

## Linking

### Branch/PR Linking

**Compound PR linking (preferred):**
`execute_operation("complete_task_with_review", { taskId, prUrl, comment: "PR opened: <title>" })` — links the PR, sets
status to `awaiting_review`, and posts a comment in one call.

- PR exists → `execute_operation("link_pr_to_task", { taskId, prUrl })` (auto-assigns if unassigned, posts GitHub PR
  comment)
- Branch only (no PR yet) → `execute_operation("add_task_comment", { taskId, content })`:
  `Started work on branch \`branch-name\``
- Post each link **once per session**

### Full Sync

Complete sync workflow (user asks to sync, or auto-trigger fires):

1. Proceed with MCP calls (OAuth at transport; stop on auth failure — 401, unauthorized, or `Not authenticated`)
2. Diff context: `git log --oneline -10`, `git diff --stat main...HEAD`
3. Task lookup (fast chain) — `entity_lookup` also returns existing comments
4. **Dedup:** if the most recent comment covers the same branch/scope with no new progress → skip, confirm "no updates"
5. Status update (skip if already correct; Acceptance Check before marking complete)
6. Comment — pick the format: Review Summary after a review, Decision Comment after a spike, Bugfix Comment for a fix,
   otherwise Progress Comment
7. Branch/PR linking if applicable
8. Confirm what was synced (include task URL)

---

## Complex Operations

For multi-step or multi-entity operations (bulk updates, project archiving, subtask hierarchy, tag management, task
prioritization), use `execute_operation("manage_project", { request })` with a natural-language request. It routes to an
AI agent that handles the right sequence of actions (10–30 seconds).
