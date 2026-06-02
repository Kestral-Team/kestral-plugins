# Kestral Plugin

Connect Claude Code (or Codex CLI) to [Kestral](https://app.kestral.ai) — an AI-powered project management tool for
teams. Kestral stores your projects, tasks, documents, and customer feedback, and gives an AI agent context about all of
it.

This plugin lets you work with Kestral directly from the chat: onboard a project from a folder of docs, search and
update tasks, pull workspace knowledge into a conversation, or scaffold a new project with tasks.

## Why use it

- **Onboard a holistic project in one command.** Point the plugin at a folder of docs. It scans, infers a title, and —
  using the tools you've already connected (Slack, Notion, Google Drive, Linear, Jira, Granola, and more) — pulls in
  related documents and tasks so the project reflects your whole picture, not just local files.
- **Bring your connected tools' context with you.** The plugin sees the same MCP connectors loaded in your session and
  offers to enrich the project with them. You stay in control of what's included — nothing is pulled without your say.
- **Manage tasks without switching tools.** List your open tasks, change status, add comments, and assign work from the
  command line.
- **Give the agent your workspace context.** Search Kestral for docs, projects, and tasks, then pull them into the
  conversation so the agent can answer questions with real data.
- **Plan new projects quickly.** Describe a goal, review a draft plan with tasks, and create it in Kestral with one
  approval.

## Install

### Claude Code

```
/plugin marketplace add Kestral-Team/kestral-plugins
/plugin install kestral@kestral-plugins
```

### Codex CLI

```
codex plugin marketplace add Kestral-Team/kestral-plugins
codex plugin add kestral@kestral-plugins
```

After install:

1. Run `/plugins` — confirm **kestral** is listed under the **kestral-plugins** marketplace and **enabled** (press Space to toggle).
2. **Fully quit and restart** Codex (CLI or app) so it reloads the plugin cache.
3. Run `codex plugin marketplace upgrade` if you previously installed an older build.
4. In a new thread, type `$` and look for `kestral-setup`, `kestral-tasks`, `kestral-context`, or `kestral-plan`. Or type `@kestral` to target the plugin.

Codex does **not** use Claude-style `/kestral:…` slash commands — use `$skill-name` or `@kestral` instead.

## What you can do

| Command            | What it does                                                              | Example                                                                                    |
| ------------------ | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `/kestral:kestral-setup`    | Onboard a project from a folder of docs, with tasks from connected tools. | `/kestral:kestral-setup` → authenticates, scans `./docs`, shows a manifest, uploads to Kestral.     |
| `/kestral:tasks`   | Search, view, and update tasks in your workspace.                         | `/kestral:tasks show my open tasks in the auth project` → returns a filtered task list.    |
| `/kestral:context` | Pull docs, projects, and tasks into the chat as context.                  | `/kestral:context auth migration` → finds matching docs and tasks, asks which to load.     |
| `/kestral:plan`    | Scaffold a new project with seed tasks from a brief.                      | `/kestral:plan migrate OAuth to OIDC` → drafts a project with 8 tasks, waits for approval. |

There are also lower-level skills you can call directly:

| Command                | What it does                                                       |
| ---------------------- | ------------------------------------------------------------------ |
| `/kestral:scan-folder` | Preview a folder scan without uploading anything.                  |
| `/kestral:scan-tasks`  | Detect task tools (Linear, Jira, etc.) and list importable tasks.  |
| `/kestral:upload`      | Upload documents and create a project (used by `kestral-setup` internally). |

In Claude Code, type `/kestral:` and use autocomplete to see all available commands.
In Codex, type `@kestral` to target the plugin, or invoke a bundled skill directly with `$kestral-setup`,
`$kestral-tasks`, `$kestral-context`, or `$kestral-plan`.

## Getting started

Run `/kestral:kestral-setup` to start. The skill walks you through four steps:

1. **Authenticate** — on first use, the MCP client opens a browser for OAuth login. Tokens are managed and refreshed
   automatically.

2. **Pick a folder (and any connected sources)** — it asks which folder to scan and reminds you it can also pull context
   from tools you've connected (Slack, Notion, Google Drive, Linear, Jira, …). Name any source you'd like included, or
   just give it a folder. It won't interrogate you source-by-source — mention what you want and it reacts.

3. **Review the manifest** — a summary of your project: local documents, any documents and tasks pulled from connected
   tools, and a title/description it inferred. Every item is labelled by source. You can add, remove, or edit anything
   before proceeding.

4. **Upload** — creates a Kestral project, uploads documents, triggers Project Brain generation (an AI-generated summary
   Kestral builds from your docs), and imports tasks. You get a link to your new project, plus a nudge to open the brain
   for blockers and a few next steps it can help with — adding more context, working the blocker tasks, or sharing with
   your team.

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

After onboarding, use `/kestral:tasks` to work with your tasks, `/kestral:context` to pull knowledge into conversations,
and `/kestral:plan` to create new projects.

## Supported document and task sources

### Documents

| Source               | File types                                | Notes                                                                                    |
| -------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| Local folder         | `.md`, `.txt`, `.doc`, `.docx`            | Scanned recursively. Hidden dirs, `node_modules/`, `dist/`, etc. are excluded.           |
| MCP document sources | Granola, Notion, Google Drive, Confluence, Slack | Detected automatically when the MCP is loaded. Nothing is pulled in unless you ask for it. |

### Tasks

Any task tool loaded in the session — Linear, Jira, GitHub Issues, Asana, ClickUp, Shortcut, and others. Open tasks plus
tasks completed in the **last 30 days** are imported. The plugin detects these tools automatically via the Model Context
Protocol (the way Claude Code talks to external tools).

## Troubleshooting

| Problem                   | Fix                                                                                                                            |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Auth expired or invalid   | Reconnect the `kestral` MCP server (`/mcp`) to re-authenticate via OAuth.                                                     |
| Folder not found          | Double-check the path. Use an absolute path or `~` shorthand.                                                                  |
| No eligible files found   | The folder must contain `.md`, `.txt`, `.doc`, or `.docx` files.                                                               |
| Project Brain not enabled | "Project Brain isn't enabled for this workspace" — ask your workspace admin to enable it, then generate from the project page. |
| MCP won't connect         | Verify the MCP server is running (`/mcp` should show kestral as connected). Restart Claude Code and retry.                                                      |
| Network errors            | Check your connection. If the error persists, run `/kestral:kestral-setup` again.                                                       |
| Codex: plugin added but no skills | Upgrade to **v0.4.5+** (`codex plugin marketplace upgrade`), restart Codex, enable the plugin in `/plugins`. Older builds used `disable-model-invocation`, which hides skills from Codex entirely. |
| Codex: plugin not in `/plugins` | Re-run `codex plugin add kestral@kestral-plugins`, then restart. Check `~/.codex/config.toml` for `[plugins."kestral@kestral-plugins"]` with `enabled = true`. |


## Re-running `/kestral:kestral-setup`

Each run creates a **fresh project**. There is no update-in-place yet.
## Links

- [Kestral app](https://app.kestral.ai)
- [Public plugin repo](https://github.com/Kestral-Team/kestral-plugins)

