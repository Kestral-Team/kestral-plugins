---
name: kestral-tasks
description: Use when the user explicitly asks to list, inspect, update, assign, or comment on Kestral tasks, or invokes /kestral:tasks or $kestral-tasks.
---

# Tasks

Search, view, and update tasks in your Kestral workspace without leaving the chat.

## Prerequisites

The `Kestral` MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth (browser opens on first use).

## Human-readable references

Keep Kestral IDs internal unless the user asks for them. In user-facing output:

- Tasks: show `slug - title` when a slug is available, linked with `url` when the host can render links.
- Projects, documents, feedback, customers, tags, statuses, and other Kestral entities: show the readable name/title/label
  first, linked with `url` when the host can render links.
- People and actors: show display names; if unresolved, write `Unknown member (id: <rawId>)`.
- Unknown non-member entities: write `Unknown <entity type> (id: <rawId>)`.
- Approval tables and write-back plans must put the human-readable label first. Raw URLs, machine IDs, source IDs, and
  bare slugs belong only in secondary metadata when useful.
- Use existing display fields first; do extra lookups only for entities that matter to the answer.

## Workflow

### 1. Authenticate

OAuth is automatic. On a 401, reconnect the MCP server (see Error handling).

### 2. Parse intent

The user's prompt determines which path to follow:

| User says                                                                            | Intent         | Path   |
| ------------------------------------------------------------------------------------ | -------------- | ------ |
| "show my tasks", "list open tasks in auth project"                                   | **List**       | Step 3 |
| "show task AUTH-12", "get details on AUTH-12"                                        | **Drill-down** | Step 4 |
| "mark AUTH-12 done", "assign AUTH-12 to Sarah", "comment on AUTH-12: shipped in PR #42" | **Update**  | Step 5 |

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

#### 3c. Resolve display values

Before rendering, prefer display fields already returned by the task search result: `slug`, `title`, `url`,
`statusName`, `priorityLabel`, `projectName`, and any display-name fields.

If a rendered row has `assigneeId` or `createdById` but no readable name, call `list_members` once, build an ID-to-name
map, and use it for all rows. If a member ID still cannot be resolved, render `Unknown member (id: <rawId>)`.

#### 3d. Render results

Show a compact table. Use task slug + title as the user-facing handle. Link the handle when `url` is available.

```markdown
Tasks (12 results):

| Task | Status | Priority | Assignee |
| --- | --- | --- | --- |
| [AUTH-12 - Migrate OAuth tokens to new format](https://app.kestral.ai/workspace/abc/task/example1) | In Progress | High | Alice Chen |
| AUTH-13 - Update redirect handler | To Do | Medium | Unassigned |

Say a task slug or title to see details, or describe an update ("mark AUTH-12 done").
```

If zero results: "No tasks matched those filters. Try broadening the search."

### 4. Drill-down

If the user gives a slug or title from the displayed list, map it back to that row's task ID before lookup; if it is
ambiguous or not in the list, search or ask one clarifying question.

Call `entity_lookup({ id: taskId, type: "task" })`.

Render:

```markdown
Task [AUTH-12 - Migrate OAuth tokens to new format](https://app.kestral.ai/workspace/abc/task/example1)

  Status:      In Progress
  Priority:    High
  Assignee:    Alice Chen
  Created by:  Bob Park
  Project:     Auth Overhaul
  Due:         2026-07-01
  Tags:        auth, migration

  Description:
    Migrate existing OAuth 1.0 tokens to the new OIDC format...

  Subtasks:
    -

  Recent comments:
    Bob Park (2026-06-09): "Started token audit — 3 of 5 providers migrated."
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
I'll update AUTH-12 - Migrate OAuth tokens to new format:
  • Status: In Progress → Done
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

> Updated AUTH-12 - Migrate OAuth tokens to new format: status → Done. Added comment: "Shipped in PR #312".

If the write fails, show the error and suggest retrying or reconnecting the MCP server if it's an auth issue.

## Error handling

| Failure                      | Message                                                                                   |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| 401 / unauthorized           | "Authentication expired. Please reconnect the MCP server to re-authenticate."             |
| Task not found               | "Task `<reference>` not found in your workspace. Double-check the reference."              |
| Project not found for filter | "I couldn't find a project matching `<query>`. Try a different name."                     |
| Write failed                 | "Update failed: `<error>`. Try again, or reconnect the MCP server if it's an auth issue." |
