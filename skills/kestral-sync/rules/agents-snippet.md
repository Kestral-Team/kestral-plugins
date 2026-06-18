<!-- Kestral Sync — paste this section into your AGENTS.md or CLAUDE.md -->

## Kestral Sync

Keep Kestral in sync with your coding work via the Kestral MCP tools. Use judgment — skip for trivial one-off fixes,
debugging notes, or exploratory sketches.

For full procedures (comment formats, task creation, acceptance check): invoke the kestral-sync skill (`/kestral:sync`
in Claude Code, `$kestral-sync` in Codex).

### Workflow

**Starting new work:**

1. Fast lookup: extract slug from branch name → `entity_lookup`; or `query_entities({ branchName })` for exact
   branch→task match; or `query_entities({ assigneeFilter: "me" })` filtered to active/in-progress tasks. Use `research`
   only as a last resort (10–30s).
2. If a task is found and assigned to someone else with active status → warn the user (conflict). If unassigned or
   backlog → link to it rather than creating a duplicate.
3. If no match, proceed — offer to create a task after the work takes shape.

**During implementation:** post a progress comment via `comment_task` after each meaningful phase. Do NOT update on
every commit or minor edit.

**After completing work:** run the Acceptance Check from the skill, then update task status based on PR merge state: use
the workspace's review/pending status if any linked PR is open/unmerged; only mark complete/done when the PR is
**merged**. Never mark a task complete while its PR is unmerged. Post a final progress comment. Prefer
`link_pr_to_task({ statusKey, comment })` for atomic PR link + status + comment in one call. Use `list_statuses` to
discover valid status keys — never hardcode them.

**On branch push** (when a Kestral task is linked):

- First push: `update_task` (status if still todo, plus `branchName`) + `comment_task` (Progress Comment) +
  `link_pr_to_task` if a PR exists.
- Subsequent pushes: `comment_task` only if meaningful new progress since the last comment.
- No PR yet: post `Started work on branch \`branch-name\``.

**Review / bugfix / spike:** use the skill's comment formats (Review Summary, Decision Comment, Bugfix Comment) rather
than improvising.

### Conflict Check

After resolving a task via `entity_lookup`:

1. Compare `entity.assigneeId` against `whoami().memberId`
2. Done (any assignee) → verify against codebase before redoing
3. Null assignee + Todo/Backlog, or matches current user → no conflict
4. Different assignee + active status → **conflict** — warn with `assigneeName`, `statusName`, `prLinks`
5. Ask: proceed / coordinate / pick a different task

### MCP Tools Quick Reference

| Action                          | Tool                             |
| ------------------------------- | -------------------------------- |
| Find task by slug or ID         | `entity_lookup`                  |
| Find task by branch             | `query_entities({ branchName })` |
| Filter tasks by status/keyword  | `query_entities`                 |
| Deep concept search             | `research` (last resort)         |
| Discover status keys            | `list_statuses`                  |
| Update status / register branch | `update_task`                    |
| Post comment                    | `comment_task`                   |
| Link PR (atomic)                | `link_pr_to_task`                |
| Create task                     | `create_tasks`                   |
| Check auth                      | `whoami`                         |
| Complex operations              | `project_management`             |
