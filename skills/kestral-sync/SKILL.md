---
name: kestral-sync
description: >-
  Sync session progress to Kestral via the MCP sync_session_workflow operation. Use after push,
  phase completion, PR creation, or review conclusion. Ambient hooks call this for you when enabled.
---

# Kestral Sync

Keep the linked Kestral task in sync with this coding session. Full playbooks live on the server and are returned by the
MCP operation — do not invent sync procedures from memory.

## How to sync

Call:

```text
execute_operation("sync_session_workflow", { intent })
```

| Intent             | When                                               |
| ------------------ | -------------------------------------------------- |
| `session_start`    | Beginning of a linked-repo session (hooks do this) |
| `pickup`           | Starting work on a task                            |
| `update`           | Progress, review, status, comments                 |
| `create`           | Explicitly creating a task for current work        |
| `update_or_create` | Prefer `sync_after_push` after push/PR instead     |
| `repo_opt_in`      | Resolving home auto-sync prefs for this folder     |

Optional `workType`: omit or `"coding"` (default) for branch/PR/milestone playbooks; `"general"` for non-coding
comment/status/create (no branch/PR).

Follow the returned `instructions` and call listed ops by `operationId`. Do **not** call `search_operations` first for
sync/pickup/push.

### After push / PR

Prefer one call:

```text
execute_operation("sync_after_push", { branchName, summary?, prUrl? })
```

Do not run Full Sync afterward.

### Opt out of GitHub auto-link / auto-create

For chore or one-off work with no Kestral task, call
`execute_operation("set_pr_tracking", { tracked: false, branchName, prUrl? })` as soon as the branch is known (before
the PR exists). Fall back to `<!-- kestral:skip-auto-link -->` in the PR body only if MCP is unavailable. To undo an
auto-created task: pass `removeAutoCreatedTask: true` with `prUrl`.

## Never write MCP into product code

`execute_operation` / MCP tool calls are agent-session actions only. Never write them into application source.

## When to sync

- After `git push`, `gt submit`, or `gh pr create`
- Structured plan written — offer tracking tasks; ask one parent for the plan vs a task per phase/deliverable
  (`intent: create` if approved)
- Phase or feature complete
- PR created or linked
- Review, bugfix, or prototype conclusion
- User asks to sync

Skip for: review-feedback fixes, CI fixes, dep bumps, lint fixes, no new progress since last comment.

## Auth failures

If any sync call returns an auth error (401, unauthorized), stop. Ask the user to re-authenticate. Do not retry until
they confirm.
