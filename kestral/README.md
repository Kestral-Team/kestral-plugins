# Kestral Plugin

Connect Claude Code (or Codex CLI) to [Kestral](https://app.kestral.ai) — an AI-powered project
management tool for teams. Kestral stores your projects, tasks, documents, and customer feedback, and
gives an AI agent context about all of it.

This plugin lets you work with Kestral directly from the chat: onboard a project from a folder of docs,
search and update tasks, pull workspace knowledge into a conversation, or scaffold a new project with
tasks.

## Why use it

- **Onboard a project in one command.** Point the plugin at a folder of docs. It scans, infers a title,
  imports tasks from Linear/Jira/GitHub, and creates a Kestral project — all before you leave the chat.
- **Manage tasks without switching tools.** List your open tasks, change status, add comments, and
  assign work from the command line.
- **Give the agent your workspace context.** Search Kestral for docs, projects, and tasks, then pull
  them into the conversation so the agent can answer questions with real data.
- **Plan new projects quickly.** Describe a goal, review a draft plan with tasks, and create it in
  Kestral with one approval.

## Install

### Claude Code

```
/plugin marketplace add Kestral-Team/kestral-plugins
/plugin install kestral@kestral-plugins
```

### Codex CLI

```
codex plugin marketplace add Kestral-Team/kestral-plugins
codex plugin install kestral@kestral-plugins
```

> Codex install commands are provisional — verify the literal syntax during first Codex walkthrough.

## What you can do

| Command | What it does | Example |
| --- | --- | --- |
| `/kestral:init` | Onboard a project from a folder of docs, with tasks from connected tools. | `/kestral:init` → authenticates, scans `./docs`, shows a manifest, uploads to Kestral. |
| `/kestral:tasks` | Search, view, and update tasks in your workspace. | `/kestral:tasks show my open tasks in the auth project` → returns a filtered task list. |
| `/kestral:context` | Pull docs, projects, and tasks into the chat as context. | `/kestral:context auth migration` → finds matching docs and tasks, asks which to load. |
| `/kestral:plan` | Scaffold a new project with seed tasks from a brief. | `/kestral:plan migrate OAuth to OIDC` → drafts a project with 8 tasks, waits for approval. |

There are also lower-level skills you can call directly:

| Command | What it does |
| --- | --- |
| `/kestral:scan-folder` | Preview a folder scan without uploading anything. |
| `/kestral:scan-tasks` | Detect task tools (Linear, Jira, etc.) and list importable tasks. |
| `/kestral:upload` | Upload documents and create a project (used by `init` internally). |

Type `/kestral:` and use autocomplete to see all available commands.

## Getting started

Run `/kestral:init` to start. The skill walks you through four steps:

1. **Authenticate** — opens a browser tab at `app.kestral.ai/cli-auth`. Approve in your browser. The
   plugin picks up your API key automatically and saves it to `~/.kestral/credentials`.

2. **Pick a folder** — "Which folder should I scan?" Point it at your project root or a docs subfolder.

3. **Review the manifest** — a summary of your project: documents it found, tasks from any connected
   tools (Linear, Jira, GitHub Issues, etc.), and a title/description it inferred. You can add, remove,
   or edit anything before proceeding.

4. **Upload** — creates a Kestral project, uploads documents, triggers Project Brain generation (an
   AI-generated summary Kestral builds from your docs), and imports tasks. You get a link to your new
   project.

```
Project: My App
Description: React app with Express backend for task management

Documents (8 total, ~42 KB):
  • README.md                    (12.1 KB)  [local]
  • docs/architecture.md         (8.3 KB)   [local]
  • docs/api.md                  (6.7 KB)   [local]
  …

Tasks (12 total):
  • Fix auth redirect loop                  [linear, high]
  • Add dark mode toggle                     [linear, medium]
  • … and 10 more

Approve, edit, or cancel?
```

After onboarding, use `/kestral:tasks` to work with your tasks, `/kestral:context` to pull knowledge
into conversations, and `/kestral:plan` to create new projects.

## Supported document and task sources

### Documents

| Source | File types | Notes |
| --- | --- | --- |
| Local folder | `.md`, `.txt`, `.doc`, `.docx` | Scanned recursively. Hidden dirs, `node_modules/`, `dist/`, etc. are excluded. |
| MCP document sources | Granola, Notion, Google Drive, Confluence | Detected automatically when the MCP is loaded. You're asked before anything is included. |

### Tasks

Any task tool loaded in the session — Linear, Jira, GitHub Issues, Asana, ClickUp, Shortcut, and
others. Open tasks plus tasks completed in the **last 30 days** are imported. The plugin detects these
tools automatically via the Model Context Protocol (the way Claude Code talks to external tools).

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Auth expired or invalid | Run `/kestral:init` again — the skill re-runs the auth flow when credentials are missing or invalid. |
| Folder not found | Double-check the path. Use an absolute path or `~` shorthand. |
| No eligible files found | The folder must contain `.md`, `.txt`, `.doc`, or `.docx` files. |
| `pandoc` not installed | Install `pandoc` (see below). Without it, `.doc`/`.docx` files are skipped. |
| Project Brain not enabled | "Project Brain isn't enabled for this workspace" — ask your workspace admin to enable it, then generate from the project page. |
| MCP won't connect | See the "For contributors" section below to verify the server is running. |
| Network errors | Check your connection. If the error persists, run `/kestral:init` again. |

## If you have `.doc`/`.docx` files

Word documents are converted to plain text via `pandoc` during upload. Tables, embedded images, and
complex formatting are dropped. Install `pandoc` before running `/kestral:init`:

```bash
# macOS
brew install pandoc

# Ubuntu/Debian
sudo apt-get install pandoc
```

If `pandoc` is not installed, `.doc`/`.docx` files are skipped with a warning.

## Re-running `/kestral:init`

Each run creates a **fresh project**. There is no update-in-place yet.

## For contributors

### Local development

1. Start `server` (port 3000) and `client` (port 5173). The MCP endpoint is at `localhost:3000/mcp`.
2. Set `CLIENT_URL=http://localhost:5173` in `server/.env` for CLI auth redirects.
3. `.mcp.json` points at `http://localhost:3000/mcp` — the port must match.
4. After changing `.mcp.json`, fully quit Claude Code and restart. Run `/mcp` — `kestral` must show
   **connected**.
5. Type `/kestral:` and use autocomplete to see all available slash commands.

### Skills reference

| Skill | Purpose |
| --- | --- |
| [`init`](skills/init/SKILL.md) | Authenticate, scan folder, build manifest, upload to Kestral |
| [`tasks`](skills/tasks/SKILL.md) | Search, view, and update tasks |
| [`context`](skills/context/SKILL.md) | Pull docs, projects, and tasks into the chat |
| [`plan`](skills/plan/SKILL.md) | Scaffold a project with seed tasks from a brief |
| [`scan-folder`](skills/scan-folder/SKILL.md) | Preview folder scan without uploading |
| [`scan-tasks`](skills/scan-tasks/SKILL.md) | Detect and list tasks from connected tools |
| [`upload`](skills/upload/SKILL.md) | Upload documents and create a project |

### Spec reference

- [Manifest copy spec](docs/manifest-copy-spec.md) — canonical manifest format, edit grammar, error
  messages for `init` and `plan` skills

## Links

- [Kestral app](https://app.kestral.ai)
- [Public plugin repo](https://github.com/Kestral-Team/kestral-plugins)
