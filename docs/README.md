# Kestral Plugin

Connect Claude Code, Claude Cowork, or Codex to [Kestral](https://app.kestral.ai) — an AI-powered project management tool for
teams. Kestral stores your projects, tasks, documents, and customer feedback, and gives an AI agent context about all of
it.

This plugin lets you work with Kestral directly from the chat: onboard a project from your connected tools, search and
update tasks, pull workspace knowledge into a conversation, or scaffold a new project with tasks.

## Why use it

- **Onboard a project in one command.** Tell the plugin what you're working on. It pulls in tasks from Linear, Jira,
  and GitHub, links documents from Notion, Google Drive, and Slack, and creates a Kestral project with everything
  organized — including a Project Brain that gives the agent context about your work. You can also include local files
  if you have relevant docs.
- **Bring your connected tools' context with you.** The plugin sees the same MCP connectors loaded in your session and
  offers to enrich the project with them. You stay in control of what's included — nothing is pulled without your say.
- **Manage tasks without switching tools.** List your open tasks, change status, add comments, and assign work from the
  command line.
- **Give the agent your workspace context.** Search Kestral for docs, projects, and tasks, then pull them into the
  conversation so the agent can answer questions with real data.
- **Plan new projects quickly.** Describe a goal, review a draft plan with tasks, and create it in Kestral with one
  approval.

## Install

**Recommended:** one command connects to Kestral at `https://app.kestral.ai/mcp` and installs to detected apps
(Claude Code and/or Codex on macOS and Linux; Claude Cowork is macOS only):

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
```

Pick targets non-interactively (e.g. Codex only):

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex
```

The script checks prerequisites and registers the marketplace. On macOS it can also install to Claude Cowork (writes
plugin files under `~/Library/Application Support/Claude/`).
[View source](https://github.com/Kestral-Team/kestral-plugins/blob/main/setup.sh) or download first:
`curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh -o kestral-setup.sh && less kestral-setup.sh` then `bash kestral-setup.sh`.

### Advanced: local file upload (macOS only)

Use this if you need to upload many files from your computer. Installs a small local helper at
`~/.kestral/bin/kestral-mcp`:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --go-mcp
```

Requires **git** and **Ruby** (included with macOS).

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
6. Kestral is set up automatically when the plugin installs — no extra configuration. If Kestral isn't available in a new chat, fully quit and restart Cowork, then try again.
7. In Cowork, run `/kestral-setup` to sign up or login, connect your workspace, and start onboarding.

### Codex App

1. Open **Plugins**, click **More**, then select **Add more**.
2. In the repository field, enter `Kestral-Team/kestral-plugins` and leave the bottom two fields blank.
3. Click **More** again, then find **Kestral Plugins**.
4. Click **+** in the **Productivity** section for the plugin called **Kestral**.
5. Run `/kestral-setup` in Codex to connect your workspace.

   Codex does **not** use Claude-style `/kestral:…` slash commands for other skills — use `$kestral-setup`,
   `$kestral-tasks`, `$kestral-context`, or `$kestral-plan`, or type `@kestral` to target the plugin.

After installing in Codex, fully quit and restart the app so it reloads the plugin cache. In a new thread, type `$` and
look for `kestral-setup`, `kestral-tasks`, `kestral-context`, or `kestral-plan`.

## What you can do

| Command            | What it does                                                              | Example                                                                                    |
| ------------------ | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `/kestral:kestral-setup`    | Onboard a project from connected tools, goals, and optional local files. | `/kestral:kestral-setup` → authenticates, finds your work, shows a manifest, creates a Kestral project.     |
| `/kestral:tasks`   | Search, view, and update tasks in your workspace.                         | `/kestral:tasks show my open tasks in the auth project` → returns a filtered task list.    |
| `/kestral:context` | Pull docs, projects, and tasks into the chat as context.                  | `/kestral:context auth migration` → finds matching docs and tasks, asks which to load.     |
| `/kestral:plan`    | Scaffold a new project with seed tasks from a brief.                      | `/kestral:plan migrate OAuth to OIDC` → drafts a project with 8 tasks, waits for approval. |

In Claude Code, type `/kestral:` and use autocomplete to see all available commands.
In Codex, type `@kestral` to target the plugin, or invoke a bundled skill directly with `$kestral-setup`,
`$kestral-tasks`, `$kestral-context`, or `$kestral-plan`.

## Getting started

Run `/kestral:kestral-setup` to start. The skill walks you through four steps:

1. **Authenticate** — on first use, the MCP client opens a browser for OAuth login. Tokens are managed and refreshed
   automatically.

2. **Describe your work** — it asks what you're working on and checks for connected tools (Slack, Notion, Google Drive,
   Linear, Jira, …). You can point it at wherever your context lives — apps, files, repos, or just describe the goal.
   It won't interrogate you source-by-source — mention what you want and it reacts.

3. **Review the manifest** — a summary of your project: tasks and documents pulled from connected tools, any local files
   you included, and a title/description it inferred. Every item is labelled by source. You can add, remove, or edit
   anything before proceeding.

4. **Create** — creates a Kestral project, attaches documents, triggers Project Brain generation (an AI-generated
   summary Kestral builds from your context), and imports tasks. You get a link to your new project, plus a few next
   steps it can help with — adding more context, working blocker tasks, or sharing with your team.

```
Recommended setup:

1. Auth Migration
   Why: Linear project "Auth", recent GitHub PRs, and matching Drive design docs.
   Tasks: 12 selected [linear], 43 more matching.
   Documents: 6 selected [google_drive, notion], 8 more candidates.
   Confidence: high.

2. Billing Automation
   Why: GitHub issues and Jira tasks reference billing workflow.
   Tasks: 7 selected [jira, github], 19 more matching.
   Documents: 4 selected [notion].
   Confidence: high.

Say "create these", "only create Auth Migration", "rename Billing Automation to Payments",
or "import all matching tasks into Auth Migration".
```

After onboarding, use `/kestral:tasks` to work with your tasks, `/kestral:context` to pull knowledge into conversations,
and `/kestral:plan` to create new projects.

## Supported document and task sources

### Documents

| Source               | File types                                | Notes                                                                                    |
| -------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| MCP document sources | Notion, Google Drive, Slack, Confluence   | Linked into Kestral with source provenance (not copied). Detected automatically when the MCP is loaded. Nothing is pulled in unless you ask for it. |
| Local files          | `.md`, `.txt`, `.doc`, `.docx`, and more  | Include specific files or point at a folder. Hidden dirs, `node_modules/`, `dist/`, etc. are excluded. |

### Tasks

Any task tool loaded in the session — Linear, Jira, GitHub Issues, Asana, ClickUp, Shortcut, and others. Open tasks plus
tasks completed in the **last 30 days** are imported. The plugin detects these tools automatically via the Model Context
Protocol (the way Claude Code talks to external tools).

## Troubleshooting

| Problem                   | Fix                                                                                                                            |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Auth expired or invalid   | Reconnect the `Kestral` MCP server (`/mcp`) to re-authenticate via OAuth.                                                     |
| Project Brain not enabled | "Project Brain isn't enabled for this workspace" — ask your workspace admin to enable it, then generate from the project page. |
| MCP won't connect         | Default (remote MCP): re-run the setup script, restart your AI app, and confirm **Kestral** in `/mcp`. **macOS `--go-mcp` only:** re-run with `--go-mcp` so `.mcp.json` gets a `/Users/...` absolute path (not `~/.kestral/...`). Check the helper: `ls ~/.kestral/bin/kestral-mcp`. Re-run `/kestral:kestral-setup` or sign in from [Integrations](https://app.kestral.ai). |
| Network errors            | Check your connection. If the error persists, run `/kestral:kestral-setup` again.                                                       |
| Local file upload fails   | File upload requires the local MCP binary (`--go-mcp`) or presigned-URL upload tools. You can also upload files manually from the Kestral project page. |
| Codex: plugin added but no skills | Restart Codex after install. Enable the plugin under **Plugins** if it is disabled. Upgrade to the latest build from **Kestral Plugins** if you installed an older version. |
| Codex: plugin not listed          | Repeat the install steps above (Plugins → More → Add more). After restart, confirm **Kestral** appears under **Kestral Plugins**. |

## Re-running `/kestral:kestral-setup`

Each run creates a **fresh project**. There is no update-in-place yet.

## Links

- [Kestral app](https://app.kestral.ai)
- [Public plugin repo](https://github.com/Kestral-Team/kestral-plugins)
