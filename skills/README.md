# Kestral Plugin Skills

Each folder here is a skill bundled with the Kestral plugin. A skill is a `SKILL.md` instruction file (plus optional
`agents/` definitions) that the host agent loads when you invoke it. Folder names must match the `name` field in
`SKILL.md` frontmatter so hosts can discover direct invocations reliably. For install instructions and plugin-level
docs, see the [plugin README](../README.md).

## Invoking a skill

| Host                        | How to invoke                                                                                         |
| --------------------------- | ----------------------------------------------------------------------------------------------------- |
| Claude Code / Claude Cowork | `/kestral:<skill>` — e.g. `/kestral:tasks`, `/kestral:sync`. Type `/kestral:` for autocomplete.       |
| Codex                       | `$kestral-<name>` — e.g. `$kestral-tasks`, `$kestral-sync` — or type `@kestral` to target the plugin. |

All skills require the **Kestral** MCP server in this session. Every skill calls `whoami` first — if it succeeds,
proceed; if it fails (401), the agent cannot handle OAuth directly — guide the user to authenticate through their app's
UI (Cowork: Customize → Connectors; Codex: Settings → MCP Servers → Authenticate; Claude Code: `/mcp` → reconnect).
See the plugin [README](../README.md#troubleshooting) for platform-specific troubleshooting.

## User-facing skills

### `kestral-setup` — onboard a project

Help the user set up a **Kestral project with a Project Brain** — a living work summary for themselves, agents, and
team. Pulls context from connected tools (Linear, Jira, GitHub, Notion, Drive, Granola, …); local files only when
offered. If projects already exist, surfaces brain contents and suggests next steps they can take right now.

- **When to use:** first-time setup, or organizing work into a Kestral project with a brain you can work from immediately.
- **Example:** `/kestral:kestral-setup` → explains what a Kestral project with a brain gives you, asks where context
  lives, shows manifest, creates the project. Existing workspaces: surfaces brain contents + next steps you can take now.
- **Note:** each run creates a fresh project — there is no update-in-place. Composes `kestral-scan-tasks` and
  `kestral-upload` internally; dispatches `kestral-scan-folder` only when the user provides local files.

### `kestral-tasks` — search, view, and update tasks

Work with Kestral tasks without leaving the chat: filtered lists, task details, status changes, comments, assignment.

- **When to use:** "show my open tasks", "move AUTH-12 to in progress", "comment on the auth task".
- **Example:** `/kestral:tasks show my open tasks in the auth project` → returns a filtered task list.

### `kestral-context` — pull workspace knowledge into the chat

Searches your Kestral workspace for documents, projects, and tasks matching a topic, asks which results to load, and
pulls them into the conversation so the agent can answer with real workspace data.

- **When to use:** the agent needs Kestral knowledge to answer a question — "what's the latest on the auth migration?"
- **Example:** `/kestral:context auth migration` → finds matching docs and tasks, asks which to load.

### `kestral-plan-day` — plan today from your daily brief

Turns Kestral's daily brief, relevant project/task state, and your calendar (today + next two days) into a realistic,
ranked plan with focus blocks. Asks about constraints before finalizing; if no calendar connector is available, it asks
for your fixed commitments instead.

- **When to use:** starting the workday, prioritizing today, turning the morning brief into action.
- **Example:** `/kestral:plan-day` → summarizes updates, asks constraints, drafts focus blocks.

### `kestral-end-day-review` — close out the day

Produces an evidence-backed review of today — what got done, what didn't — proposes write-backs to relevant Kestral
project brains, and drafts a priority list for tomorrow. Always asks before writing anything back to Kestral or local
files.

- **When to use:** wrapping up the day, reconciling project state, prepping tomorrow.
- **Example:** `/kestral:end-day-review` → reviews today's trail, proposes updates, asks before writing.

### `kestral-sync` — keep Kestral in sync while you code

Ambient sync between your coding agent and Kestral: conflict detection before building, plain-language progress
comments, status transitions, and PR linking — mostly automatic via the companion rule/snippet, with a manual "sync now"
escape hatch.

- **When to use:** install the [companion rule/snippet](kestral-sync/README.md) for ambient sync; invoke manually to
  force an immediate sync.
- **Example:** `/kestral:sync` → checks for conflicts, posts progress, links PRs.
- **Note:** ambient-first — the primary install is the always-on rule (Cursor) or AGENTS.md snippet (Claude Code,
  Codex). See the [sync README](kestral-sync/README.md) for per-platform install instructions.

## Lower-level building blocks

These are composed by `kestral-setup` but can be invoked directly when you want just one step.

### `kestral-scan-folder` — select and inspect local files

Selects and inspects local files from a folder or explicit file list and produces a curated document manifest — no
upload. Used by `kestral-setup` when the user provides local files.

- **When to use:** previewing which local files would be included before running setup.
- **Example:** `/kestral:scan-folder ./docs`
- **Note:** file upload uses presigned URLs and requires network egress to `storage.googleapis.com`. On Claude Cowork,
  enable **Allow network egress** in **Settings → Capabilities** and add `storage.googleapis.com` and `app.kestral.ai`.
  On Codex, enable **Allow network access** in **Settings → Configuration**. Text/markdown files can always be created
  as inline documents without egress.

### `kestral-scan-tasks` — detect importable tasks

Detects task-shaped MCP tools in the session (Linear, Jira, GitHub Issues, Asana, …), lists open tasks plus tasks
completed in the last 30 days, and translates them to the Kestral import schema.

- **When to use:** checking which external tasks would be importable before running setup.
- **Example:** `/kestral:scan-tasks`

### `kestral-upload` — execute an approved manifest

Creates a Kestral project from an approved manifest: attaches documents (using the best available upload strategy),
triggers Project Brain generation, and imports tasks if provided by the caller.

- **When to use:** you already have an approved manifest (usually from `kestral-setup`) and just want the upload step.
- **Example:** `/kestral:upload`

## Skill anatomy

```
skills/kestral-<name>/
  SKILL.md     # frontmatter (name, description) + workflow instructions the agent follows
  agents/      # optional subagent definitions used by the skill (not present in all skills)
```

The `description` frontmatter controls when hosts surface the skill automatically; the workflow body is what the agent
executes once invoked. When editing a skill, keep the main [plugin README](../README.md) command tables in sync.
