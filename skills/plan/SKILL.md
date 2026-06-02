---
name: kestral-plan
description: Scaffold a new Kestral project with tasks from a goal or brief. Use only when the user explicitly asks to plan or scaffold a project.
---

# Plan

Create a new Kestral project with seed tasks from a goal, brief, or conversation. The skill drafts a project plan, lets
you review and edit it, then creates everything in Kestral with one approval.

## Prerequisites

- The Kestral MCP server must show as **connected** (`/mcp` → `kestral` connected).
- The `kestral` MCP server must be connected. Authentication is handled automatically via OAuth — the MCP client opens a browser for login on first use.

## Workflow

### 1. Authenticate

Authentication is handled automatically via OAuth. If a tool call fails with 401, tell the user to reconnect the MCP server.

### 2. Get the brief

The user's prompt after `/kestral:plan` is the project brief. Examples:

- `/kestral:plan migrate auth from OAuth1 to OIDC`
- `/kestral:plan build a customer feedback dashboard — needs data pipeline, UI, and alerting`
- `/kestral:plan` (empty — ask: "What's the goal or brief for this project?")

Accept free text. The brief can be a single sentence or multiple paragraphs.

### 3. Check for duplicates

Call `search_projects({ query: "<inferred title from brief>", limit: 5 })`.

If any results look like a match, show them:

```
I found existing projects that might overlap:

  1. Auth Overhaul            (active, 12 tasks)
  2. OAuth Migration Planning (planned, 3 tasks)

Create a new project anyway, or add tasks to one of these? (new / 1 / 2)
```

- If the user picks an existing project, skip project creation (step 6) and go straight to task creation within that
  project.
- If the user says "new" or there are no matches, continue to step 4.

### 4. Draft the plan

From the brief, draft:

- **Title** — short project name (2–6 words).
- **Description** — 1–3 sentences explaining the goal.
- **Tasks** — 3–15 actionable tasks, each with:
  - `title` — clear, imperative ("Migrate OAuth tokens", not "Token migration").
  - `priority` — `urgent` (1), `high` (2), `medium` (3), `low` (4), or `none` (0). Default to `medium` unless the brief
    signals urgency.
  - `description` — optional, 1–2 sentences if the task needs clarification.

Order tasks by suggested execution sequence (dependencies first). Omit the priority bracket for `none` (0) priority
tasks — only display `[urgent]`, `[high]`, `[medium]`, or `[low]` when set.

### 5. Render the plan manifest and checkpoint

Show the plan for review using the checkpoint grammar from `../../docs/manifest-copy-spec.md`:

```
Project: Auth OIDC Migration
Description: Migrate from legacy OAuth 1.0 to OpenID Connect for all auth flows.

Tasks (8):
  1. [high]    Audit current OAuth endpoints and token formats
  2. [high]    Set up OIDC provider in staging
  3. [medium]  Write token migration script
  4. [medium]  Update login flow to use OIDC
  5. [medium]  Update API auth middleware
  6. [medium]  Write migration rollback script
  7. [low]     Update developer documentation
  8. [low]     QA full auth flow on staging

Tags: auth, migration

Approve, edit, or cancel?
```

**Supported checkpoint commands:**

| Command                                                   | Effect                                          |
| --------------------------------------------------------- | ----------------------------------------------- |
| **approve** / **yes** / **go**                            | Create the project and tasks in Kestral         |
| **cancel** / **no**                                       | Exit — no Kestral API calls                     |
| **add** `<task title>`                                    | Append a task (default priority: medium)        |
| **add** `<task title>` `[high]`                           | Append a task with explicit priority            |
| **remove** `<number>` or **remove** `<title>`             | Remove a task by number or title match          |
| **title:** `<new title>` / **change title** `<new>`       | Override project title (new-project only)       |
| **description:** `<new>` / **change description** `<new>` | Override project description (new-project only) |
| **reorder** `<number>` **to** `<position>`                | Move a task to a different position             |
| **reprioritize** `<number>` `<priority>`                  | Change a task's priority                        |
| **tag:** `<tag1>, <tag2>`                                 | Set tags to apply to the project after creation |

Re-render the manifest after each edit. Loop until the user approves or cancels.

**Task count limit:** If the user `add`s beyond **15 tasks**, warn: "That's a lot of tasks for one project. Consider
splitting into multiple projects, or approve and I'll create them all."

### 6. Create the project

On approve:

**6a. Create project.** Call `kestral_create_project`:

```json
{
  "title": "<title>",
  "description": "<description>"
}
```

Store `projectId` and `url` from the response.

**6b. Create tasks.** Call `kestral_create_project_tasks`:

```json
{
  "projectId": "<projectId>",
  "tasks": [
    {
      "title": "Audit current OAuth endpoints and token formats",
      "source": "plugin",
      "priority": 2,
      "description": "..."
    }
  ]
}
```

The `source` field is always `"plugin"` for tasks created by this skill.

**6c. Apply tags** (optional). If the user specified tags at the checkpoint, call `assign_tag` for each tag:

```json
{
  "workObjectId": "<projectId>",
  "workObjectType": "Project",
  "tagName": "<tag>"
}
```

Tags that don't exist yet are auto-created by the MCP server.

### 7. Present results

> Your project is ready: **\<url\>**
>
> Created 8 tasks. Tags applied: auth, migration.

If task creation partially failed:

> Your project is ready: **\<url\>**
>
> Created 6 of 8 tasks. 2 could not be created — you can add them manually in Kestral.

If project creation failed entirely, surface the error and suggest retrying.

## Adding tasks to an existing project

If the user chose an existing project at step 3:

- Skip step 6a (project already exists).
- At step 4, draft only the tasks (no title/description edits).
- At step 5, show a simplified manifest:

```
Adding tasks to: Auth Overhaul (active, 12 existing tasks)

New tasks (5):
  1. [medium]  Write token migration script
  2. [medium]  Update login flow to use OIDC
  …

Approve, edit, or cancel?
```

- On approve, call `kestral_create_project_tasks` with the existing project ID.

## Cancel behavior

On cancel: "Cancelled. No changes were made in Kestral."

## Error handling

| Failure                  | Message                                                                                   |
| ------------------------ | ----------------------------------------------------------------------------------------- |
| 401 / unauthorized       | "Authentication expired. Please reconnect the MCP server to re-authenticate."             |
| Project creation failed  | "Could not create the project: `<error>`. Try again or check `/mcp`."                     |
| Task creation all failed | "Project created at `<url>`, but task creation failed. Add tasks manually."               |
| Tag assignment failed    | "Project and tasks created. Could not apply tag `<name>` — apply it manually in Kestral." |
