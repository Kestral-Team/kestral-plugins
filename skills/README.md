# Kestral Plugin Skills

Each folder here is a skill bundled with the Kestral plugin. A skill is a `SKILL.md` instruction file (plus optional
`agents/` definitions) that the host agent loads when you invoke it. For install instructions and plugin-level docs, see
the [plugin README](../README.md).

## Invoking a skill

| Host                        | How to invoke                                                                                            |
| --------------------------- | -------------------------------------------------------------------------------------------------------- |
| Claude Code / Claude Cowork | `/kestral:<skill>` — e.g. `/kestral:tasks`, `/kestral:kestral-setup`. Type `/kestral:` for autocomplete. |
| Codex                       | `$kestral-<name>` — e.g. `$kestral-tasks`, `$kestral-setup` — or type `@kestral` to target the plugin.   |

All skills require the **Kestral** MCP server to be connected (`/mcp`). Auth is automatic via OAuth — a browser window
opens on first use; on a 401, reconnect the MCP server.

## User-facing skills

### `kestral-setup` — onboard a project

Authenticate and onboard a local folder into a new Kestral project: scans documents, enriches with connected sources
(Slack, Notion, Google Drive, Linear, Jira, …), shows a manifest for approval, then uploads documents, triggers Project
Brain generation, and imports tasks.

- **When to use:** first-time setup, or any time you want to turn a folder of docs into a Kestral project.
- **Example:** `/kestral:kestral-setup` → asks which folder to scan, shows a manifest, uploads on approval.
- **Note:** each run creates a fresh project — there is no update-in-place. Composes `scan-folder`, `scan-tasks`, and
  `upload` internally.

### `tasks` — search, view, and update tasks

Work with Kestral tasks without leaving the chat: filtered lists, task details, status changes, comments, assignment.

- **When to use:** "show my open tasks", "move KES-42 to in progress", "comment on the auth task".
- **Example:** `/kestral:tasks show my open tasks in the auth project` → returns a filtered task list.

### `context` — pull workspace knowledge into the chat

Searches your Kestral workspace for documents, projects, and tasks matching a topic, asks which results to load, and
pulls them into the conversation so the agent can answer with real workspace data.

- **When to use:** the agent needs Kestral knowledge to answer a question — "what's the latest on the auth migration?"
- **Example:** `/kestral:context auth migration` → finds matching docs and tasks, asks which to load.

### `plan` — scaffold a new project from a brief

Drafts a new Kestral project with seed tasks from a goal, brief, or the current conversation. You review and edit the
draft, then it creates everything in Kestral with one approval.

- **When to use:** starting a new initiative you want tracked in Kestral.
- **Example:** `/kestral:plan migrate OAuth to OIDC` → drafts a project with seed tasks, waits for approval.

### `plan-day` — plan today from your daily brief

Turns Kestral's daily brief, relevant project/task state, and your calendar (today + next two days) into a realistic,
ranked plan with focus blocks. Asks about constraints before finalizing; if no calendar connector is available, it asks
for your fixed commitments instead.

- **When to use:** starting the workday, prioritizing today, turning the morning brief into action.
- **Example:** `/kestral:plan-day` → summarizes updates, asks constraints, drafts focus blocks.

### `end-day-review` — close out the day

Produces an evidence-backed review of today — what got done, what didn't — proposes write-backs to relevant Kestral
project brains, and drafts a priority list for tomorrow. Always asks before writing anything back to Kestral or local
files.

- **When to use:** wrapping up the day, reconciling project state, prepping tomorrow.
- **Example:** `/kestral:end-day-review` → reviews today's trail, proposes updates, asks before writing.

## Lower-level building blocks

These are composed by `kestral-setup` but can be invoked directly when you want just one step.

### `scan-folder` — preview a folder scan

Walks a local folder (or explicit file list) and produces a curated document manifest — no upload. Eligible types:
`.md`, `.txt`, `.doc`, `.docx`; hidden dirs, `node_modules/`, `dist/`, etc. are excluded.

- **When to use:** previewing what onboarding would pick up. For folders with more than ~15 eligible files, prefer
  `kestral-setup`, which adds manifest approval and enrichment.
- **Example:** `/kestral:scan-folder ./docs`

### `scan-tasks` — detect importable tasks

Detects task-shaped MCP tools in the session (Linear, Jira, GitHub Issues, Asana, …), lists open tasks plus tasks
completed in the last 30 days, and translates them to the Kestral import schema.

- **When to use:** checking which external tasks would be importable before running setup.
- **Example:** `/kestral:scan-tasks`

### `upload` — execute an approved manifest

Creates a Kestral project from a scan manifest: uploads documents via `upload_document`, triggers Project Brain
generation, and imports tasks if provided by the caller.

- **When to use:** you already have an approved manifest (usually from `scan-folder` / `kestral-setup`) and just want
  the upload step.
- **Example:** `/kestral:upload`

## Skill anatomy

```
skills/<name>/
  SKILL.md     # frontmatter (name, description) + workflow instructions the agent follows
  agents/      # optional subagent definitions used by the skill (not present in all skills)
```

The `description` frontmatter controls when hosts surface the skill automatically; the workflow body is what the agent
executes once invoked. When editing a skill, keep the main [plugin README](../README.md) command tables in sync.
