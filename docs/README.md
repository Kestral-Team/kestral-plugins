# Kestral Plugin

Connect Claude Code, Claude Cowork, or Codex to [Kestral](https://app.kestral.ai) — an AI-powered project management
tool for teams. Kestral stores your projects, tasks, documents, and customer feedback, and gives an AI agent context
about all of it.

This plugin lets you work with Kestral directly from the chat: organize scattered work into projects, search and update
tasks, pull workspace knowledge into a conversation, or scaffold a new project with tasks.

## Why use it

- **Organize scattered work into Kestral projects.** Give setup local files, a repo, GitHub, Linear, Jira, Notion,
  Google Drive, Slack, any other connected tool, or just "I'm not organized yet." It proposes a small active-workstream
  taxonomy, creates the selected Kestral projects, imports relevant tasks and documents, and starts Project Brain for
  each project.
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
Linear. **Claude Code, Claude Cowork, and Codex** all spawn it on your Mac, so you need **Node.js 20+** on your **login
PATH** (the environment GUI apps see — not just an interactive Terminal session).

**Quick check** (open Terminal):

```bash
node --version   # must print v20 or higher
which npx        # must print a path
```

| Symptom                                            | Likely cause                                     | Fast fix                                                                                                      |
| -------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `command not found` for `node` / `npx`             | Node not installed                               | Install LTS from [nodejs.org](https://nodejs.org), or `brew install node` (Mac)                               |
| `v16.x` or lower                                   | Node too old                                     | `npm install -g n && n lts` (Mac), `winget install OpenJS.NodeJS.LTS` (Windows), or reinstall from nodejs.org |
| Node works in Terminal but Kestral MCP still fails | Not on login PATH                                | Restart Mac after install, or ensure `/usr/local/bin` / `/opt/homebrew/bin` is in PATH for GUI apps           |
| Cowork: other connectors work, Kestral doesn't     | Kestral is the only plugin that needs local Node | Install Node 20+, fully quit Cowork, start a new task                                                         |

After installing or upgrading Node, **fully quit and reopen** your Claude app before retrying setup.

> **No Node?** Use `--go-mcp` to install the standalone Go `kestral-mcp` binary instead — no Node.js at runtime
> (jq is used during install). The plugin's MCP config is rewritten to launch the binary from
> `~/.kestral/bin/kestral-mcp`. The binary is taken from the plugin bundle when present, otherwise downloaded from the
> latest GitHub release.

## Install

**Recommended (macOS):** one command installs to Claude Code and Claude Desktop:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
```

**No Node.js (Go MCP binary):** pass `--go-mcp`. When piping from `curl`, use `bash -s --` so flags reach the script:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --go-mcp
```

Pick targets non-interactively (e.g. Codex only):

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --go-mcp --app codex
```

The script handles prerequisites (git, Node 20+), marketplace registration, and — for Claude Desktop — the Cowork
plugin file install. [View source](https://github.com/Kestral-Team/kestral-plugins/blob/main/setup.sh) or download
first: `curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh -o kestral-setup.sh && less kestral-setup.sh` then `bash kestral-setup.sh`.

Pick your app below for manual steps (the same steps the script automates).

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
7. The **Kestral** MCP connector registers with the plugin. Check **Customize → Connectors**; if it is missing, fully
   quit and restart Cowork.
8. The first Kestral tool call opens a browser window for OAuth sign-in.
9. In Cowork, run `/kestral:kestral-setup` to connect your workspace and start onboarding.

Setup and `upload_document` (local file uploads from disk) work the same as in Claude Code once **Kestral** is connected.

### Codex App

**Recommended:** run `bash setup.sh --app codex` for automated install. Manual GUI steps below.

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
| `/kestral:kestral-setup`    | Organize local files and connected-tool context into one or more Kestral projects. | `/kestral:kestral-setup` → scans files and connected tools, proposes 1-3 projects, imports selected context, and starts Project Brain. |
| `/kestral:tasks`   | Search, view, and update tasks in your workspace.                         | `/kestral:tasks show my open tasks in the auth project` → returns a filtered task list.    |
| `/kestral:context` | Pull docs, projects, and tasks into the chat as context.                  | `/kestral:context auth migration` → finds matching docs and tasks, asks which to load.     |
| `/kestral:plan`    | Scaffold a new project with seed tasks from a brief.                      | `/kestral:plan migrate OAuth to OIDC` → drafts a project with 8 tasks, waits for approval. |
| `/kestral:plan-day` | Turn your Kestral daily brief and calendar into a ranked plan for today. | `/kestral:plan-day` → summarizes updates, asks constraints, and drafts focus blocks.       |
| `/kestral:end-day-review` | Summarize today, reconcile project updates, and prioritize tomorrow. | `/kestral:end-day-review` → reviews today's trail, proposes write-backs, and asks before writing. |

There are also lower-level skills you can call directly:

| Command                | What it does                                                                |
| ---------------------- | --------------------------------------------------------------------------- |
| `/kestral:scan-folder` | Preview a folder scan without uploading anything.                           |
| `/kestral:scan-tasks`  | Detect task tools (Linear, Jira, etc.) and list importable tasks.           |
| `/kestral:upload`      | Upload documents and create a project (used by `kestral-setup` internally). |

In Claude Code, type `/kestral:` and use autocomplete to see all available commands. In Codex, type `@kestral` to target
the plugin, or invoke a bundled skill directly with `$kestral-setup`, `$kestral-tasks`, `$kestral-context`,
`$kestral-plan`, `$kestral-plan-day`, or `$kestral-end-day-review`.

For a detailed guide to each skill — when to use it, examples, inputs, and how the lower-level skills compose — see the
[skills README](skills/README.md).

## Getting started

Run `/kestral:kestral-setup` to start. The skill walks you through four steps:

1. **Authenticate** — on first use, the MCP client opens a browser for OAuth login.
2. **Share any source** — provide local files, GitHub, Linear, Jira, Notion, Google Drive, Slack, any other connected
   tool, or say you are not organized yet.
3. **Review the proposed projects** — setup recommends a focused set of active workstream projects, usually 1-3 and at
   most 5 by default. You can rename, split, merge, remove, use your own buckets, or ask to import more context.
4. **Create and import** — setup creates the selected projects, imports curated tasks and documents by default, honors
   larger import requests, and triggers Project Brain for each project.

```
Recommended setup:

I found 4 possible workstreams. I recommend starting with these 2 because they have the clearest active work and
supporting context.

1. Auth Reliability
   Why: Linear project, GitHub issues, and matching local architecture docs.
   Tasks: 12 selected [linear, github], 43 more matching.
   Documents: 8 selected [local, google_drive], 96 more candidates.
   Confidence: high.

2. Launch Operations
   Why: Recent Notion plans, Drive docs, and Slack threads point to active launch work.
   Tasks: 5 selected [jira].
   Documents: 6 selected [notion, google_drive, slack].
   Confidence: medium.

Say "create these", "only create Auth Reliability", "rename Launch Operations to GTM Launch", "use these buckets: ...",
or "import all matching tasks into Auth Reliability".
```

After onboarding, use `/kestral:tasks` to work with your tasks, `/kestral:context` to pull knowledge into conversations,
`/kestral:plan` to create new projects, `/kestral:plan-day` to turn your daily brief and calendar into a focus plan, and
`/kestral:end-day-review` to close out the day with project updates and tomorrow priorities.

## Supported document and task sources

### Documents

| Source                 | File types or systems                     | Notes                                                                                    |
| ---------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| Local files            | Local upload file types                 | Folders are scanned recursively. Hidden dirs, `node_modules/`, `dist/`, etc. are excluded. Convert `.doc` files to `.docx` before import. |
| Connected document tools | Notion, Google Drive, Slack, Confluence, and other connected tools | Linked into Kestral with source provenance when available. Detected automatically when the connector is loaded. |

Supported local upload extensions: `.pdf`, `.docx`, `.txt`, `.md`, `.markdown`, `.csv`, `.jpg`, `.jpeg`, `.png`,
`.webp`, `.heic`, `.heif`, `.mp3`, `.m4a`, `.mp4`.

### Tasks

Any task tool loaded in the session — Linear, Jira, GitHub Issues, Asana, ClickUp, Shortcut, and other connected tools.
Setup uses open, in-progress, recently updated, high-priority, or recently completed work as signals for active
workstreams, imports curated tasks by default, and imports more or all matching tasks when requested. The plugin detects
these tools automatically via the Model Context Protocol (the way Claude Code talks to external tools).

## Troubleshooting

| Problem                                            | Fix                                                                                                                                                                                                                                                                                                      |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Host key verification failed` on `plugin install` | Claude Code clones plugin sources over SSH and cannot prompt for GitHub's host key. Run `ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts`, then retry `claude plugin install kestral@kestral-plugins`. Or force HTTPS: `git config --global url."https://github.com/".insteadOf git@github.com:` |
| Auth expired or invalid   | Reconnect the `Kestral` MCP server (`/mcp`) to re-authenticate via OAuth.                                                     |
| Source not found          | Double-check the path, URL, connector, or tool name. Use an absolute path or `~` shorthand for local paths.                    |
| No eligible files found   | Share another local path, repo, task system, document tool, or workstream bucket to give setup a usable signal.                |
| Project Brain not enabled | "Project Brain isn't enabled for this workspace" — ask your workspace admin to enable it, then generate from the project page. |
| MCP won't connect         | First run `node --version` and `which npx` (see **Requirements**). If Node is fine, run `/mcp` and confirm **Kestral** shows connected with tools. Re-run `/kestral:kestral-setup` or sign in from [Integrations](https://app.kestral.ai). |
| Node missing or too old   | Kestral needs **Node 20+** on your Mac (all hosts). See **Requirements** above for the quick check and upgrade steps — fastest: `npm install -g n && n lts` (Mac), `winget install OpenJS.NodeJS.LTS` (Windows), or [nodejs.org](https://nodejs.org). The macOS install script also checks Node before registering the plugin. Fully quit and reopen the app after. |
| Network errors            | Check your connection. If the error persists, run `/kestral:kestral-setup` again.                                                       |
| Codex: plugin added but no skills | Restart Codex after install. Enable the plugin under **Plugins** if it is disabled. Upgrade to the latest build from **Kestral Plugins** if you installed an older version. |
| Codex: plugin not listed          | Repeat the install steps above (Plugins → More → Add more). After restart, confirm **Kestral** appears under **Kestral Plugins**. |
| Desktop: script install not visible after restart | Fully quit Claude Desktop, start a **new task**, check Customize → Plugins. If missing, use the GUI install steps above or manual removal (delete `cowork_plugins/marketplaces/kestral-plugins/`, remove `kestral@kestral-plugins` from `installed_plugins.json` and `cowork_settings.json#enabledPlugins`, remove `kestral-plugins` from `known_marketplaces.json` and `extraKnownMarketplaces`). |

## Uninstall

### Claude Code

```bash
claude plugin uninstall kestral@kestral-plugins
# optional: claude plugin marketplace remove kestral-plugins
```

### Claude Desktop

Use **Customize → Plugins** to uninstall. For manual removal if the GUI can't delete the entry, see the troubleshooting row above.

## Re-running `/kestral:kestral-setup`

Each run creates a **fresh project**. There is no update-in-place yet.

## Links

- [Kestral app](https://app.kestral.ai)
- [Public plugin repo](https://github.com/Kestral-Team/kestral-plugins)
