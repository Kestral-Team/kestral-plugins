# Kestral Plugin

[Kestral](https://app.kestral.ai) is an AI-powered project management tool for teams. It stores your
projects, tasks, documents, and customer feedback, and gives an AI agent context about all of it.

This plugin connects Claude Code, Claude Cowork, Codex, and Cursor to your Kestral workspace so you can
manage projects and tasks without leaving your AI app.

## What you can do

| Command | What it does |
| --- | --- |
| `/kestral:kestral-setup` | Onboard a project from a folder of docs. Scans files, imports tasks from Linear/Jira/GitHub, and creates a Kestral project. |
| `/kestral:kestral-tasks` | Search, view, and update tasks. Filter by status, priority, project, or assignee. |
| `/kestral:kestral-context` | Pull documents, projects, and tasks into the conversation so the agent can answer questions with real workspace data. |
| `/kestral:kestral-plan-day` | Turn your Kestral daily brief and calendar into a ranked plan for today. |
| `/kestral:kestral-end-day-review` | Summarize today, reconcile project updates, and prioritize tomorrow. |

In Claude Code, run `/kestral:kestral-setup` first to authenticate and create your first project.
In Codex, type `@kestral` to target the plugin, or invoke a bundled skill directly with `$kestral-setup`, `$kestral-plan-day`, or `$kestral-end-day-review` (not `/kestral:…` slash commands). The Codex marketplace installs Kestral by default; use `/plugins` to confirm it is enabled.

## Install

**Quick install (macOS and Linux):** one command connects to Kestral at `https://app.kestral.ai/mcp` and installs to
**Claude Code, Claude Cowork, Codex, and Cursor** (all detected apps). Re-run it anytime to update existing installs.
Prerequisites: **git** (and **Ruby** for Claude Cowork — included with macOS). Claude Cowork is macOS only; open it and
sign in at least once first, so the script can find your Cowork session.

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
```

Non-interactive examples:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-code
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-cowork
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app cursor
```

For a clean reset, add `--full-reinstall` to remove Kestral plugin files, cached plugin data, and saved sign-in state
before reinstalling:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --full-reinstall
```

**Note:** The script registers the Kestral marketplace via the `claude`/`codex` CLI, and for Claude Cowork writes
directly to Cowork's plugin files under `~/Library/Application Support/Claude/`.
[View the script source](https://github.com/Kestral-Team/kestral-plugins/blob/main/setup.sh) before running.

### Claude Code

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-code
```

Fully quit and reopen Claude Code (or reload plugins), then run `/kestral:kestral-setup` in chat.

If you prefer to install by hand, use `/plugin marketplace add Kestral-Team/kestral-plugins` then
`/plugin install kestral@kestral-plugins`. To update an existing install, run
`claude plugin update kestral@kestral-plugins` — `plugin install` reports "already installed" and leaves the old version
in place.

### Codex

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex
```

Fully quit and reopen Codex, start a new thread, then open `/hooks` and trust the Kestral hooks — until you do, Codex
skips session-start and push/PR sync reminders. Then run `$kestral-setup`.

### Cursor

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app cursor
```

Fully quit and restart Cursor. Open **Settings → Tools & MCPs** and click **Connect** on **Kestral** if authentication is
required.

Team admins can add marketplace `Kestral-Team/kestral-plugins` at [cursor.com/dashboard](https://cursor.com/dashboard) →
Settings → Plugins.

The Cursor plugin bundles task sync, plan-day, and end-day-review skills plus the hosted MCP connection.

## Uninstall

### Claude Code

```bash
claude plugin uninstall kestral@kestral-plugins
# optional: claude plugin marketplace remove kestral-plugins
```

### Claude Desktop

Use **Customize → Plugins** to uninstall the Kestral plugin.

If the GUI cannot see or delete the entry, remove manually:

1. Delete `cowork_plugins/marketplaces/kestral-plugins/` under your Desktop session root
   (`~/Library/Application Support/Claude/local-agent-mode-sessions/<accountId>/<orgId>/`).
2. Remove the `kestral@kestral-plugins` entry from `cowork_plugins/installed_plugins.json`.
3. Remove `kestral@kestral-plugins` from `cowork_settings.json` → `enabledPlugins`.
4. Remove the `kestral-plugins` key from `cowork_plugins/known_marketplaces.json` and from
   `cowork_settings.json` → `extraKnownMarketplaces` if present.

## Version

Current release: **v0.4.38**

## Links

- [Kestral app](https://app.kestral.ai)
- [Full plugin documentation](./docs/README.md)
