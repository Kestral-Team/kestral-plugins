<!-- Kestral Sync — paste this section into your AGENTS.md or CLAUDE.md -->

## Kestral Sync

Keep Kestral in sync with your coding work via the Kestral MCP tools. Use judgment — skip for trivial one-off fixes,
debugging notes, or exploratory sketches.

For full procedures (comment formats, task creation, acceptance check): invoke the kestral-sync skill (`/kestral:sync`
in Claude Code, `$kestral-sync` in Codex).

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

**After completing work:** run the Acceptance Check from the skill, then update task status based on PR merge state: use
the workspace's review/pending status if any linked PR is open/unmerged; only mark complete/done when the PR is
**merged**. Never mark a task complete while its PR is unmerged. Post a final progress comment. Prefer
`execute_operation("complete_task_with_review", { taskId, prUrl, summary })` for atomic PR link + status + comment in
one call. Use `list_statuses` to discover valid status keys — never hardcode them.

**On branch push** (when a Kestral task is linked):

- First push: `execute_operation("update_task", { taskId, statusKey })` (if still todo) +
  `execute_operation("register_branch_on_task", { taskId, branchName })` +
  `execute_operation("add_task_comment", { taskId, content })` +
  `execute_operation("link_pr_to_task", { taskId, prUrl })` if a PR exists. Or use
  `execute_operation("claim_task_and_branch", { taskId, branchName })` to combine assign + status + branch + comment.
- Subsequent pushes: `execute_operation("add_task_comment", ...)` only if meaningful new progress since the last
  comment.
- No PR yet: post `Started work on branch \`branch-name\``.

**Review / bugfix / spike:** use the skill's comment formats (Review Summary, Decision Comment, Bugfix Comment) rather
than improvising.

### GitHub PR bodies — link vs skip auto-link

When opening a PR (`gh pr create`), choose one:

- **Tracked feature/fix (has a Kestral task):** omit skip directive; after create call
  `execute_operation("link_pr_to_task", { taskId, prUrl })`. Optionally include task slug in the title for webhook
  auto-link.
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

| Action                    | Tool                                                                                |
| ------------------------- | ----------------------------------------------------------------------------------- |
| Get member identity       | `whoami` (primary — when `memberId` needed for Conflict Check or Candidate Ranking) |
| Get task details          | `entity_lookup` (primary)                                                           |
| Discover status keys      | `list_statuses` (primary)                                                           |
| Find task by branch       | `execute_operation("find_task_by_branch", { branchName })`                          |
| Keyword search (my tasks) | `execute_operation("search_my_tasks_by_keyword", { keyword, statusFilter? })`       |
| Semantic task search      | `execute_operation("search_tasks", { query })`                                      |
| List my active tasks      | `execute_operation("list_my_active_tasks", {})`                                     |
| Filter tasks by status    | `execute_operation("list_tasks_by_status", { statusFilter, projectId? })`           |
| Deep concept search       | `execute_operation("deep_research", { query })` (last resort)                       |
| Update status             | `execute_operation("update_task", { taskId, statusKey })`                           |
| Register branch           | `execute_operation("register_branch_on_task", { taskId, branchName })`              |
| Post comment              | `execute_operation("add_task_comment", { taskId, content })`                        |
| Link PR                   | `execute_operation("link_pr_to_task", { taskId, prUrl })`                           |
| Create task               | `execute_operation("create_task", { projectId, title, ... })`                       |
| Claim + start work        | `execute_operation("claim_task_and_branch", { taskId, branchName })`                |
| Complete with PR          | `execute_operation("complete_task_with_review", { taskId, prUrl, summary })`        |
| Complex operations        | `execute_operation("manage_project", { request })`                                  |
