---
name: kestral-pickup
description: >-
  Resume a Kestral-tracked multi-phase effort in a fresh chat or git worktree: download the shared
  plan document, pick (or accept) a parallel lane, conflict-check it, claim the phase task and
  branch, and load just enough context to start. Use at the start of a new worktree or clean chat,
  or when asked to pick up the plan, resume the Kestral effort, start a lane, or continue where the
  handoff left off — or when invoking /kestral:pickup or $kestral-pickup.
---

# Kestral Pickup

The receiving end of `multiphase-plan` and `kestral-handoff`. A fresh chat has no memory of prior sessions — this skill
rebuilds working context from Kestral (the durable source of truth), so a coding agent in **any** git worktree can grab
an unblocked lane and start. Designed for parallel worktrees (Conductor, `git worktree add`, or equivalent): each
worktree runs this and claims a different lane.

## Prerequisites

The `Kestral` MCP server must be in this session (`/mcp`). Authentication is handled by the MCP connection — proceed
directly. If any call returns auth failure (401, unauthorized, or `Not authenticated`), ask the user to reconnect or
authenticate the **Kestral** MCP server through their app's UI (Cowork: Customize → Connectors; Codex: authenticate
then start a new thread using `/new` — CLI: `codex mcp login Kestral`; app: Plugins → Kestral → MCP servers gear; Claude Code:
`/mcp` → reconnect; Cursor: Settings → Tools & MCPs → Connect).

## Human-readable references

Keep Kestral IDs internal unless the user asks for them. In user-facing output:

- Tasks: show `slug - title` when a slug is available, linked with `url` when the host can render links.
- Projects, documents, and other Kestral entities: show the readable name first, linked with `url` when possible.
- People: show display names; if unresolved, write `Unknown member (id: <rawId>)`.

## Entrypoint

Expected invocations include:

- `/kestral:pickup`
- `$kestral-pickup`
- "Pick up the Kestral plan in this worktree."
- "Resume the multi-phase effort and claim the next unblocked lane."

## Canonical plan format

Parse phases, lanes, and `[status: …]` markers using the canonical format.

- **MCP workflow:** use `context.plan_format` from this response — do not try to read a local file.
- **Plugin skill on disk:** if `context.plan_format` is absent, read
  `../multiphase-plan/references/plan-format.md`.

If `context.statuses` is present, map generic status terms to those workspace keys. Otherwise call `list_statuses` when
claiming (or delegate to `kestral-sync`, which owns status discovery).

## Workflow

### 1. Find the effort and download the plan

Resolve the project + plan document:

1. **Argument:** project name / plan-doc URL / task slug → `entity_lookup` (URL/slug) or `search_operations` →
   `search_projects` / `find_documents`.
2. **Local copy already here:** if `.kestral/plan.md` exists in the worktree, use its header coordinates (`projectId`,
   `workContextId`) — but still re-fetch from Kestral to get the latest, since another worktree may have handed off
   since.
3. **Ask** which project to resume if ambiguous.

Download the current plan: `execute_operation("get_document_content", { workContextId })` (follow `isTruncated` /
`nextOffset` if paged). Save it to `.kestral/plan.md` with the header comment block from the canonical format.
Optionally pull the Project Brain for background (`entity_lookup({ type: "project_brain", id: projectId })`, or invoke
`kestral-context`) — keep it to a short digest, don't dump it.

### 2. Pick a lane

Parse the plan's phases, lanes, and `[status: …]` markers, and reconcile with live task status (`entity_lookup` on the
phase tasks, or `list_tasks_by_status`). Then:

- **If the user named a lane/phase** → use it.
- **Otherwise** show the lanes with their state and recommend the next **unblocked** one (all its `Depends on` phases
  are `done`, and it isn't already `in-progress` in another worktree):

  > **[project] — [effort]** · N phases in M lanes.
  > - **Lane A:** Phase 1 ✅ done · Phase 3 ⏳ ready ← recommended
  > - **Lane B:** Phase 2 🔒 claimed (in progress, another worktree)
  > - **Integration:** Phase 4 — blocked on Lane A + B
  >
  > Which lane should this worktree take? (recommend Lane A / Phase 3)

Do not start integration phases until their dependency phases are `done`.

### 3. Conflict-check before claiming

Apply `kestral-sync`'s **Conflict Check** so two worktrees don't collide:

- Is the chosen phase's task already assigned / `in-progress` (claimed by another worktree)? If so, warn with assignee +
  status and offer a different lane.
- Read the plan's **Conflict watch**: if a sibling lane in flight touches the same files, surface it now so the user
  sequences merges deliberately.

### 4. Claim the phase

Confirm with the user, then claim the task + branch. Prefer invoking **`kestral-sync`** (it owns branch derivation,
`claim_task_and_branch`, status discovery, and the already-linked conflict signal). Use the phase's **Suggested branch**
from the plan as the branch name. Create/switch to that git branch in the worktree — the worktree, commits, and PR all
inherit this name, so it must describe the work.

**If the suggested branch is missing or non-descriptive** (a bare `phase-N`, an `<effort>-phase-N`, or just a number),
do not use it — derive a descriptive `<type>/<imperative-outcome-slug>` from the phase title instead (e.g. phase "Add
OAuth token refresh endpoint" → `feat/oauth-token-refresh`) and offer to fix the plan's `Suggested branch` line on the
next `kestral-handoff`.

> Claiming **[slug] - <phase title>** on branch `feat/oauth-token-refresh`, set to In Progress. Proceed?

### 5. Load focused context and start

Pull only what this phase needs — its task description (*Depends on* / *Touches* / *Done when*), the relevant plan
sections, and any linked docs/brain bullets. Summarize in a few lines, then explore the code paths the phase *Touches*
and outline the first concrete steps. Hand control back to the user to begin implementation.

> Ready on **Phase 3 — <title>**. Done when: <criteria>. Touches: <areas>. First steps: …
> When this lane advances or you switch worktrees, run **`/kestral:handoff`** (Codex: **`$kestral-handoff`**) to
> repush the plan.

## Cross-agent notes

Everything needed to resume comes from the **Kestral plan doc + phase tasks**, re-downloaded fresh — so it doesn't
matter which agent or worktree wrote the last handoff. Use only Kestral MCP + git + local files; reference both
`/kestral:name` and `$kestral-name` invocation. Delegate claim/status/conflict mechanics to `kestral-sync` rather than
reimplementing them.
