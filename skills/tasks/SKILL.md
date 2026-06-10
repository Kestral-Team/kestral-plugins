---
name: kestral-tasks
description: Search, view, and update Kestral tasks from the chat. Use only when the user explicitly asks to list, inspect, or update tasks.
---

# Tasks

Search, view, and update tasks in your Kestral workspace without leaving the chat.

## Prerequisites

The `Kestral` MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth (browser opens on first use).

## Workflow

### 1. Authenticate

OAuth is automatic. On a 401, reconnect the MCP server (see Error handling).

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

If the user asks for "my" tasks, use `assigneeFilter: "me"` in the `query_entities` call. The OAuth token identifies the
user automatically — no `whoami` call or manual member ID lookup is needed.

#### 3b. Build filters

`query_entities` with `type: "tasks"` uses natural language — include the user's intent directly in the `query` parameter. The tool handles
status, priority, tag, date, and project filtering via semantic search and AI parameter extraction internally.

| User phrase                   | Parameter                                                   |
| ----------------------------- | ----------------------------------------------------------- |
| "my tasks"                    | `query: "my tasks"`, `assigneeFilter: "me"`                 |
| "unassigned"                  | `query: "unassigned tasks"`, `assigneeFilter: "unassigned"` |
| "in project X"                | `query: "tasks in project X"`                               |
| "tagged bug"                  | `query: "tasks tagged bug"` (tag resolution is automatic)   |
| "due this week"               | `query: "tasks due this week"`                              |
| "urgent", "high priority"     | `query: "urgent tasks"` or `query: "high priority tasks"`   |
| "open", "in progress", "done" | `query: "open tasks"` or `query: "in progress tasks"`       |

Call `query_entities` with `type: "tasks"` and the assembled query.

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

Call `entity_lookup({ id: taskId, type: "task" })`.

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

- **Status:** call `list_statuses` to map "done" → the workspace's status ID/key.
- **Assignee:** call `list_members` to map "Sarah" → member ID.
- **Tag:** call `list_tags({ search: "<name>" })` to verify the tag exists (or note it will be auto-created).
- **Project:** call `query_entities({ type: "projects", query: "<name>" })` to resolve project ID.

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

| Action              | Tool                 | Key params                                           |
| ------------------- | -------------------- | ---------------------------------------------------- |
| Change status       | `update_task`        | `taskId`, `statusKey` or `statusId`                  |
| Change priority     | `update_task`        | `taskId`, `priority`                                 |
| Change assignee     | `update_task`        | `taskId`, `assigneeId`                               |
| Unassign            | `update_task`        | `taskId`, `unassign: true`                           |
| Change title        | `update_task`        | `taskId`, `title`                                    |
| Change description  | `update_task`        | `taskId`, `description`                              |
| Set due date        | `update_task`        | `taskId`, `dueDate` (YYYY-MM-DD)                     |
| Clear due date      | `update_task`        | `taskId`, `dueDate: null`                            |
| Move to project     | `update_task`        | `taskId`, `projectId`                                |
| Remove from project | `update_task`        | `taskId`, `projectId: null`                          |
| Archive             | `update_task`        | `taskId`, `archive: true`                            |
| Add comment         | `comment_task`       | `taskId`, `content` (markdown)                       |
| Add tag             | `project_management` | `request`: "Assign tag '<tagName>' to task <taskId>" |
| Remove tag          | `project_management` | `request`: "Remove tag '<tagId>' from task <taskId>" |

Multiple updates to the same task can be batched into one `update_task` call (e.g. status + assignee). Comments are
separate calls. Tag operations use the `project_management` agent.

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
