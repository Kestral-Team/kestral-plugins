---
name: kestral-tasks
description: Search, view, and update Kestral tasks from the chat. Use only when the user explicitly asks to list, inspect, or update tasks.
---

# Tasks

Search, view, and update tasks in your Kestral workspace without leaving the chat.

## Prerequisites

- The Kestral MCP server must show as **connected** (`/mcp` → `kestral` connected).
- The `kestral` MCP server must be connected. Authentication is handled automatically via OAuth — the MCP client opens a
  browser for login on first use.

## Workflow

### 1. Authenticate

Authentication is handled automatically via OAuth. If a tool call fails with 401, tell the user to reconnect the MCP
server.

### 2. Parse intent

The user's prompt determines which path to follow:

| User says                                                                            | Intent         | Path   |
| ------------------------------------------------------------------------------------ | -------------- | ------ |
| "show my tasks", "list open tasks in auth project"                                   | **List**       | Step 3 |
| "show task AbC123", "get details on AbC123"                                          | **Drill-down** | Step 4 |
| "mark AbC123 done", "assign AbC123 to Sarah", "comment on AbC123: shipped in PR #42" | **Update**     | Step 5 |

If the intent is ambiguous, ask one clarifying question.

### 3. List tasks

#### 3a. Resolve "my tasks"

If the user asks for "my" tasks (or any assignee-filtered query):

1. Call `kestral_whoami` — it returns `workspaceId`, `workspaceName`, and `memberId`.
2. Use the returned `memberId` for assignee filtering. No local config file or manual user selection needed — the OAuth
   token identifies the user automatically.

#### 3b. Build filters

Map the user's prompt to `search_tasks` parameters:

| User phrase                           | Parameter                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "open", "todo", "in progress", "done" | `statuses` — call `list_task_statuses` first to discover the exact keys for the workspace                                                                                                                                                                                                                                                                                               |
| "urgent", "high", "medium", "low"     | `priority`                                                                                                                                                                                                                                                                                                                                                                              |
| "in project X"                        | `projectId` — call `search_projects({ query: "X", limit: 5 })` to resolve the ID                                                                                                                                                                                                                                                                                                        |
| "my tasks"                            | `assigneeFilter: "assigned"` with the `memberId` from `kestral_whoami` as a post-filter (match on `assigneeId`). The API has no `assigneeId` parameter, so **paginate**: fetch pages of 50 (`limit: 50`), post-filter each page, accumulate matches until you have 20 user tasks or the page returns fewer than 50 results (end of data). Cap at 3 pages (150 rows) to bound API calls. |
| "unassigned"                          | `assigneeFilter: "unassigned"`                                                                                                                                                                                                                                                                                                                                                          |
| "tagged bug"                          | `tagIds` — call `list_workspace_tags({ search: "bug" })` to resolve the ID                                                                                                                                                                                                                                                                                                              |
| "due this week" / "due before June 1" | `dueDateFrom` / `dueDateTo`                                                                                                                                                                                                                                                                                                                                                             |

Call `search_tasks` with the assembled filters. Default `limit: 20`. For "my tasks" (assignee post-filter), use
`limit: 50` per page and paginate as described above.

#### 3c. Render results

Show a compact table:

```
Tasks (12 results):

  ID       | Title                          | Status      | Priority | Assignee
  ─────────┼────────────────────────────────┼─────────────┼──────────┼──────────
  AbC123   | Fix auth redirect loop         | in_progress | high     | Sarah
  XyZ789   | Add dark mode toggle           | todo        | medium   | —
  …

Say a task ID to see details, or describe an update ("mark AbC123 done").
```

If zero results: "No tasks matched those filters. Try broadening the search."

### 4. Drill-down

Call `get_task({ taskId, includeComments: true, includeSubtasks: true })`.

Render:

```
Task AbC123: Fix auth redirect loop

  Status:      in_progress
  Priority:    high
  Assignee:    Sarah
  Project:     Auth Overhaul
  Due:         2026-06-15
  Tags:        bug, auth

  Description:
    The OAuth redirect is looping when the session cookie…

  Subtasks (2):
    • AbC124  Investigate cookie SameSite flag    [done]
    • AbC125  Update redirect handler             [todo]

  Recent comments (3):
    Sarah (May 20): "Reproduced on Chrome 130…"
    Dev (May 22): "SameSite=Lax fixes it locally."
    Sarah (May 24): "Deploying fix in PR #312."
```

After rendering, prompt: "What would you like to do? (update status, comment, assign, go back to list)"

### 5. Update

All updates require confirmation before calling the write tool.

#### 5a. Resolve references

Before writing, resolve any human-readable references to IDs:

- **Status:** call `list_task_statuses` to map "done" → the workspace's status ID/key.
- **Assignee:** call `list_workspace_members` to map "Sarah" → member ID.
- **Tag:** call `list_workspace_tags({ search: "<name>" })` to verify the tag exists (or note it will be auto-created).
- **Project:** call `search_projects({ query: "<name>" })` to resolve project ID.

#### 5b. Confirm

Show exactly what will change:

```
I'll update task AbC123:
  • Status: in_progress → done
  • Comment: "Shipped in PR #312"

Confirm? (yes / no)
```

Wait for explicit confirmation. On "no", cancel and return to the drill-down or list.

#### 5c. Execute

Depending on the update type, call one or more tools:

| Action              | Tool               | Key params                                                  |
| ------------------- | ------------------ | ----------------------------------------------------------- |
| Change status       | `update_task`      | `taskId`, `statusKey` or `statusId`                         |
| Change priority     | `update_task`      | `taskId`, `priority`                                        |
| Change assignee     | `update_task`      | `taskId`, `assigneeId`                                      |
| Unassign            | `update_task`      | `taskId`, `unassign: true`                                  |
| Change title        | `update_task`      | `taskId`, `title`                                           |
| Change description  | `update_task`      | `taskId`, `description`                                     |
| Set due date        | `update_task`      | `taskId`, `dueDate` (YYYY-MM-DD)                            |
| Clear due date      | `update_task`      | `taskId`, `dueDate: null`                                   |
| Move to project     | `update_task`      | `taskId`, `projectId`                                       |
| Remove from project | `update_task`      | `taskId`, `projectId: null`                                 |
| Archive             | `update_task`      | `taskId`, `archive: true`                                   |
| Add comment         | `add_task_comment` | `taskId`, `content` (markdown)                              |
| Add tag             | `assign_tag`       | `workObjectId: taskId`, `workObjectType: "Task"`, `tagName` |
| Remove tag          | `unassign_tag`     | `workObjectId: taskId`, `workObjectType: "Task"`, `tagId`   |

Multiple updates to the same task can be batched into one `update_task` call (e.g. status + assignee). Comments and tags
are separate calls.

#### 5d. Report

After each write, confirm what changed:

> Updated task AbC123: status → done. Added comment: "Shipped in PR #312".

If the write fails, show the error and suggest retrying or reconnecting the MCP server if it's an auth issue.

## Error handling

| Failure                      | Message                                                                                   |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| 401 / unauthorized           | "Authentication expired. Please reconnect the MCP server to re-authenticate."             |
| Task not found               | "Task `<id>` not found in your workspace. Double-check the ID."                           |
| Project not found for filter | "I couldn't find a project matching `<query>`. Try a different name."                     |
| Write failed                 | "Update failed: `<error>`. Try again, or reconnect the MCP server if it's an auth issue." |
