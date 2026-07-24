<!-- Kestral Sync — paste this section into your AGENTS.md or CLAUDE.md -->

## Kestral Sync

Keep Kestral in sync with your coding work via the Kestral MCP tools. Use judgment — skip for trivial one-off fixes,
debugging notes, or exploratory sketches.

For full procedures (comment formats, task creation, acceptance check): call
`execute_operation("sync_session_workflow", { intent })` and follow the returned playbook (or invoke the thin
`kestral-sync` skill which points at that operation).

### Workflow

**Starting new work:**

1. Fast lookup: extract slug from branch name → `entity_lookup`; or
   `execute_operation("find_task_by_branch", { branchName })` for exact branch→task match; or
   `execute_operation("list_my_active_tasks", {})` filtered to active/in-progress tasks. Use
   `execute_operation("deep_research", { query })` only as a last resort (10–30s).
2. If a task is found and assigned to someone else with active status → warn the user (conflict). If unassigned or
   backlog → link to it rather than creating a duplicate.
3. If no match, proceed — offer to create a task after the work takes shape.

**During implementation:** post a progress comment via `execute_operation("add_task_comment", { taskId, content })`
after each meaningful phase. Do NOT update on every commit or minor edit.

**After writing a structured plan:** offer to create tracking tasks, and ask whether they want **one parent task for the
whole plan** or **a separate task per phase/deliverable**. If the user accepts, call
`execute_operation("sync_session_workflow", { intent: "create" })` and follow the returned **From Plan** section (use
parent/subtask hierarchy correctly — checklists stay in descriptions unless a phase has independently shippable
deliverables). Never auto-create.

**After completing work:** call `execute_operation("sync_session_workflow", { intent: "update" })` and follow the
returned **Acceptance Check**, then update task status based on PR merge state: use the workspace's review/pending
status if any linked PR is open/unmerged; only mark complete/done when the PR is **merged**. Never mark a task complete
while its PR is unmerged. Post a final progress comment. Prefer
`execute_operation("complete_task_with_review", { taskId, prUrl, summary })` for atomic PR link + status + comment in
one call. Use `list_statuses` to discover valid status keys — never hardcode them.

**On branch push / submit / PR creation:** call `execute_operation("sync_after_push", { branchName, summary?, prUrl? })`
once. Do not follow it with Full Sync.

- `synced` or `skipped` → done
- `needsDecision: unlinked_branch` → ask once this session whether to create a task; never auto-create
- `needsDecision: ambiguous_branch` → ask which candidate task to update
- `needsDecision: ambiguous_pr` → ask which candidate task to update
- `partial` → report the failed part and retry the operation named by `retryOperation`

If the user approves creation, call `execute_operation("sync_session_workflow", { intent: "create" })` and follow the
returned **Unlinked Branch — Explicit Create** section. Include conversation-sourced why in the task description when
available; omit rather than invent. Remember a decline for later pushes in the same session.

**Review / bug fix / spike:** call `execute_operation("sync_session_workflow", { intent: "update" })` and use the
returned comment templates (Review Summary, Decision Comment, Bug Fix Comment) rather than improvising.

### GitHub PR bodies — link vs skip auto-link

When opening a PR (`gh pr create`), choose one:

- **Tracked feature/fix (has a Kestral task):** omit skip directive; after create use the one-call `sync_after_push`
  path above with the current branch and PR URL. Optionally include the task slug in the title for webhook auto-link.
- **Chore / manifest bump / no task:** add `<!-- kestral:skip-auto-link -->` (or `Kestral: skip auto-link`) to the PR
  body so Kestral does not enqueue AI auto-link or post no-task-linked bot comments.

### Conflict Check

After resolving a task via `entity_lookup`:

1. Compare `entity.assigneeId` against `memberId` from `whoami` (call once per session when first needed; cache and
   reuse)
2. Done (any assignee) → verify against codebase before redoing
3. Null assignee + Todo/Backlog, or matches current user → no conflict
4. Different assignee + active status → **conflict** — warn with `assigneeName`, `statusName`, `prLinks`
5. Ask: proceed / coordinate / pick a different task

### MCP Tools Quick Reference

| Action                    | Tool                                                                                                              |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Get member identity       | `whoami` (primary — when `memberId` needed for Conflict Check or Candidate Ranking)                               |
| Get task details          | `entity_lookup` (primary)                                                                                         |
| Discover status keys      | `list_statuses` (primary)                                                                                         |
| Find task by branch       | `execute_operation("find_task_by_branch", { branchName })`                                                        |
| Keyword search (my tasks) | `execute_operation("search_my_tasks_by_keyword", { keyword, statusFilter? })`                                     |
| Semantic task search      | `execute_operation("search_tasks", { query })`                                                                    |
| List my active tasks      | `execute_operation("list_my_active_tasks", {})`                                                                   |
| Filter tasks by status    | `execute_operation("list_tasks_by_status", { statusFilter, projectId? })`                                         |
| Deep concept search       | `execute_operation("deep_research", { query })` (last resort)                                                     |
| Update status             | `execute_operation("update_task", { taskId, statusKey })`                                                         |
| Register branch           | `execute_operation("register_branch_on_task", { taskId, branchName })`                                            |
| Post comment              | `execute_operation("add_task_comment", { taskId, content })`                                                      |
| Link PR                   | `execute_operation("link_pr_to_task", { taskId, prUrl })`                                                         |
| Create task               | Resolve `projectId` first (Project Selection); then `execute_operation("create_task", { projectId, title, ... })` |
| Claim + start work        | `execute_operation("claim_task_and_branch", { taskId, branchName })`                                              |
| Sync after push           | `execute_operation("sync_after_push", { branchName, summary?, prUrl? })`                                          |
| Complete with PR          | `execute_operation("complete_task_with_review", { taskId, prUrl, summary })`                                      |
| Complex operations        | `execute_operation("manage_project", { request })`                                                                |
