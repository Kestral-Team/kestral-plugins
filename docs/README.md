# Kestral Plugin

Connect Claude Code, Claude Cowork, or Codex to [Kestral](https://app.kestral.ai) — an AI-powered project management tool for
teams. Kestral stores your projects, tasks, documents, and customer feedback, and gives an AI agent context about all of
it.

This plugin lets you work with Kestral directly from the chat: onboard a project from a folder of docs, search and
update tasks, pull workspace knowledge into a conversation, or scaffold a new project with tasks.

## Why use it

- **Onboard a holistic project in one command.** Point the plugin at a folder of docs. It scans, infers a title, and —
  using the tools you've already connected (Slack, Notion, Google Drive, Linear, Jira, and more) — pulls in
  related documents and tasks so the project reflects your whole picture, not just local files.
- **Bring your connected tools' context with you.** The plugin sees the same MCP connectors loaded in your session and
  offers to enrich the project with them. You stay in control of what's included — nothing is pulled without your say.
- **Manage tasks without switching tools.** List your open tasks, change status, add comments, and assign work from the
  command line.
- **Give the agent your workspace context.** Search Kestral for docs, projects, and tasks, then pull them into the
  conversation so the agent can answer questions with real data.
- **Plan and review workdays quickly.** Describe a goal to create a project, turn your Kestral daily brief and calendar
  into a realistic plan for today, or close out the day with an evidence-backed review and tomorrow priorities.

## Requirements

Kestral's MCP bridge is a **local process** (`npx @kestral/kestral-mcp`) — not a remote HTTP connector like Slack or
Linear. **Claude Code, Claude Cowork, and Codex** all spawn it on your Mac, so you need **Node.js 20+** on your
**login PATH** (the environment GUI apps see — not just an interactive Terminal session).

**Quick check** (open Terminal):

```bash
node --version   # must print v20 or higher
which npx        # must print a path
```

| Symptom | Likely cause | Fast fix |
| --- | --- | --- |
| `command not found` for `node` / `npx` | Node not installed | Install LTS from [nodejs.org](https://nodejs.org), or `brew install node` (Mac) |
| `v16.x` or lower | Node too old | `npm install -g n && n lts` (Mac), `winget install OpenJS.NodeJS.LTS` (Windows), or reinstall from nodejs.org |
| Node works in Terminal but Kestral MCP still fails | Not on login PATH | Restart Mac after install, or ensure `/usr/local/bin` / `/opt/homebrew/bin` is in PATH for GUI apps |
| Cowork: other connectors work, Kestral doesn't | Kestral is the only plugin that needs local Node | Install Node 20+, fully quit Cowork, start a new task |

After installing or upgrading Node, **fully quit and reopen** your Claude app before retrying setup.

## Install

Pick your app and follow the steps. On first connect, Kestral opens a browser window for OAuth sign-in — no API key to
copy.

### Claude Code

1. From your terminal or within Claude Code, add the Kestral plugin marketplace:

   ```
   claude plugin marketplace add Kestral-Team/kestral-plugins
   ```

2. Install the Kestral plugin:

   ```
   claude plugin install kestral@kestral-plugins
   ```

3. In chat, run the setup skill:

   ```
   /kestral:kestral-setup
   ```

   You can also use slash commands in chat instead of the CLI: `/plugin marketplace add Kestral-Team/kestral-plugins`
   then `/plugin install kestral@kestral-plugins`.

### Claude Cowork

1. Open the **Customize** menu and go to the **Plugins** tab.
2. In **Personal plugins**, click **+**, then select **Add marketplace**.
3. Choose **Add from a repository** (sync a marketplace from a GitHub repository or git URL).
4. In the URL field, enter `Kestral-Team/kestral-plugins`, then click **Sync**.
5. Click **+** on the **Kestral** card to install the plugin.
6. If the **This plugin includes local MCP servers** dialog appears, click **Continue** to install the MCP server.
7. The **Kestral** MCP connector registers with the plugin. Check **Customize → Connectors**; if it is missing, fully quit and restart Cowork.
8. The first Kestral tool call opens a browser window for OAuth sign-in.
9. In Cowork, run `/kestral:kestral-setup` to connect your workspace and start onboarding.

Folder onboarding and `upload_document` (local file uploads from disk) work the same as in Claude Code once **Kestral** is connected.

### Codex App

1. Open **Plugins**, click **More**, then select **Add more**.
2. In the repository field, enter `Kestral-Team/kestral-plugins` and leave the bottom two fields blank.
3. Click **More** again, then find **Kestral Plugins**.
4. Click **+** in the **Productivity** section for the plugin called **Kestral**.
5. Run `/kestral-setup` in Codex to connect your workspace.

   Codex does **not** use Claude-style `/kestral:…` slash commands for other skills — use `$kestral-setup`,
   `$kestral-tasks`, `$kestral-context`, `$kestral-plan`, `$kestral-plan-day`, or `$kestral-end-day-review`, or type
   `@kestral` to target the plugin.

After installing in Codex, fully quit and restart the app so it reloads the plugin cache. In a new thread, type `$` and
look for `kestral-setup`, `kestral-tasks`, `kestral-context`, `kestral-plan`, `kestral-plan-day`, or
`kestral-end-day-review`.

## What you can do

| Command            | What it does                                                              | Example                                                                                    |
| ------------------ | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `/kestral:kestral-setup`    | Onboard a project from a folder of docs, with tasks from connected tools. | `/kestral:kestral-setup` → authenticates, scans `./docs`, shows a manifest, uploads to Kestral.     |
| `/kestral:tasks`   | Search, view, and update tasks in your workspace.                         | `/kestral:tasks show my open tasks in the auth project` → returns a filtered task list.    |
| `/kestral:context` | Pull docs, projects, and tasks into the chat as context.                  | `/kestral:context auth migration` → finds matching docs and tasks, asks which to load.     |
| `/kestral:plan`    | Scaffold a new project with seed tasks from a brief.                      | `/kestral:plan migrate OAuth to OIDC` → drafts a project with 8 tasks, waits for approval. |
| `/kestral:plan-day` | Turn your Kestral daily brief and calendar into a ranked plan for today. | `/kestral:plan-day` → summarizes updates, asks constraints, and drafts focus blocks.       |
| `/kestral:end-day-review` | Summarize today, reconcile project updates, and prioritize tomorrow. | `/kestral:end-day-review` → reviews today's trail, proposes write-backs, and asks before writing. |

There are also lower-level skills you can call directly:

| Command                | What it does                                                       |
| ---------------------- | ------------------------------------------------------------------ |
| `/kestral:scan-folder` | Preview a folder scan without uploading anything.                  |
| `/kestral:scan-tasks`  | Detect task tools (Linear, Jira, etc.) and list importable tasks.  |
| `/kestral:upload`      | Upload documents and create a project (used by `kestral-setup` internally). |

In Claude Code, type `/kestral:` and use autocomplete to see all available commands.
In Codex, type `@kestral` to target the plugin, or invoke a bundled skill directly with `$kestral-setup`,
`$kestral-tasks`, `$kestral-context`, `$kestral-plan`, `$kestral-plan-day`, or `$kestral-end-day-review`.

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
`/kestral:plan` to create new projects, `/kestral:plan-day` to turn your daily brief and calendar into a focus plan, and
`/kestral:end-day-review` to close out the day with project updates and tomorrow priorities.

## Supported document and task sources

### Documents

| Source               | File types                                | Notes                                                                                    |
| -------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| Local folder         | `.md`, `.txt`, `.doc`, `.docx`            | Scanned recursively. Hidden dirs, `node_modules/`, `dist/`, etc. are excluded.           |
| MCP document sources | Notion, Google Drive, Slack, Confluence   | Linked into Kestral with source provenance (not copied). Detected automatically when the MCP is loaded. Nothing is pulled in unless you ask for it. |

### Tasks

Any task tool loaded in the session — Linear, Jira, GitHub Issues, Asana, ClickUp, Shortcut, and others. Open tasks plus
tasks completed in the **last 30 days** are imported. The plugin detects these tools automatically via the Model Context
Protocol (the way Claude Code talks to external tools).

## Troubleshooting

| Problem                   | Fix                                                                                                                            |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Auth expired or invalid   | Reconnect the `Kestral` MCP server (`/mcp`) to re-authenticate via OAuth.                                                     |
| Folder not found          | Double-check the path. Use an absolute path or `~` shorthand.                                                                  |
| No eligible files found   | The folder must contain `.md`, `.txt`, `.doc`, or `.docx` files.                                                               |
| Project Brain not enabled | "Project Brain isn't enabled for this workspace" — ask your workspace admin to enable it, then generate from the project page. |
| MCP won't connect         | First run `node --version` and `which npx` (see **Requirements**). If Node is fine, run `/mcp` and confirm **Kestral** shows connected with tools. Re-run `/kestral:kestral-setup` or sign in from [Integrations](https://app.kestral.ai). |
| Node missing or too old   | Kestral needs **Node 20+** on your Mac (all hosts). Run the quick check above. Setup shows full upgrade steps — fastest: `npm install -g n && n lts` (Mac), `winget install OpenJS.NodeJS.LTS` (Windows), or [nodejs.org](https://nodejs.org). Fully quit and reopen the app after. |
| Network errors            | Check your connection. If the error persists, run `/kestral:kestral-setup` again.                                                       |
| Codex: plugin added but no skills | Restart Codex after install. Enable the plugin under **Plugins** if it is disabled. Upgrade to the latest build from **Kestral Plugins** if you installed an older version. |
| Codex: plugin not listed          | Repeat the install steps above (Plugins → More → Add more). After restart, confirm **Kestral** appears under **Kestral Plugins**. |


## Re-running `/kestral:kestral-setup`

Each run creates a **fresh project**. There is no update-in-place yet.

## Links

- [Kestral app](https://app.kestral.ai)
- [Public plugin repo](https://github.com/Kestral-Team/kestral-plugins)
