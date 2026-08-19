# Kestral Plugin

[Kestral](https://app.kestral.ai) is an AI-powered project management tool for teams. It stores your
projects, tasks, documents, and customer feedback, and gives an AI agent context about all of it.

This plugin connects Claude Code, Claude Cowork, Codex, and Cursor to your Kestral workspace so you can
manage projects and tasks without leaving your AI app.

## What you can do

| Command | What it does |
| --- | --- |
| `/kestral:kestral-setup` | Connect this app to Kestral and start a first plan. |
| `/kestral:kestral-tasks` | Search, view, and update tasks. Filter by status, priority, project, or assignee. |
| `/kestral:kestral-context` | Pull documents, projects, and tasks into the conversation so the agent can answer questions with real workspace data. |
| `/kestral:kestral-plan-day` | Turn your Kestral daily brief and calendar into a ranked plan for today. |
| `/kestral:kestral-end-day-review` | Summarize today, reconcile project updates, and prioritize tomorrow. |

In Claude Code, run `/kestral:kestral-setup` first to connect Kestral and start your first plan.
In Codex, type `@kestral` to target the plugin, or invoke a bundled skill directly with `$kestral-setup`, `$kestral-plan-day`, or `$kestral-end-day-review` (not `/kestral:…` slash commands). The Codex marketplace installs Kestral by default; use `/plugins` to confirm it is enabled.

## Install

**Recommended:** paste this into Cursor, Claude Code, or Codex. The agent fills `--app`, loads the plugin for that
host, then runs `kestral-setup`.

```
Install the Kestral plugin in this app, then connect and start a first plan.

curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app <this-host> --with-hooks

Fill --app with the host you are running in: cursor, claude-code, or codex.

After install, load the plugin, then run kestral-setup:
- Cursor: skills are in this session. If Kestral needs authentication, open Settings → Tools & MCPs and click Connect. Then run kestral-setup.
- Claude Code: First detect whether you're running in Desktop or CLI. Check your shell's process ancestry using whatever method is native to your OS, walking up a bounded number of levels and stopping immediately on an empty, missing, or repeated parent PID. If any ancestor is a Claude.app (or equivalent packaged desktop app) process, output exactly desktop; otherwise output exactly cli. cli: /reload-plugins, then /kestral:kestral-setup. desktop: fully quit and reopen so the plugin appears. Go to Customize → Plugins → Kestral → Connectors and click Install for the Kestral MCP connector, then fully quit and reopen again. Start a new chat and run /kestral:kestral-setup (open chats keep their old plugin and tool snapshot).
- Codex: fully quit and reopen. Authenticate (CLI: `codex mcp login Kestral`; app: Plugins → Kestral → MCP servers gear), then start a new thread using /new and run $kestral-setup.

kestral-setup walks Authorize, asks what you want to plan, and puts a multi-phase plan in Kestral.
```

**Terminal fallback (macOS and Linux):** one command connects to Kestral at `https://app.kestral.ai/mcp` and installs to
**Claude Code, Claude Cowork, Codex, and Cursor** (all detected apps). Re-run it anytime to update existing installs.
Prerequisites: **git** (and **Ruby** for Claude Cowork — included with macOS). Claude Cowork is macOS only; open it and
sign in at least once first, so the script can find your Cowork session.

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
```

Non-interactive examples:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-code --with-hooks
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-cowork --with-hooks
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex --with-hooks
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app cursor --with-hooks
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

Paste the install prompt above (fill `--app claude-code`), or use this terminal fallback:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-code --with-hooks
```

**CLI:** In chat, run `/reload-plugins`, then `/kestral:kestral-setup`. No full quit.

**Desktop:** After install, fully quit and reopen Claude so the plugin appears. Go to
**Customize → Plugins → Kestral → Connectors**, click **Install** for the Kestral MCP connector, then fully quit and reopen
Claude again. Start a **new** chat and run `/kestral:kestral-setup`. Open chats keep the plugin and tool snapshot they
started with.

If you prefer to install by hand, use `/plugin marketplace add Kestral-Team/kestral-plugins` then
`/plugin install kestral@kestral-plugins`. To update an existing install, run
`claude plugin update kestral@kestral-plugins` — `plugin install` reports "already installed" and leaves the old version
in place.

### Codex

Paste the install prompt above (fill `--app codex`), or use this terminal fallback:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex --with-hooks
```

Fully quit and reopen Codex, start a new thread (running threads never reload plugin content), then open `/hooks` and
trust the Kestral hooks — until you do, Codex skips session-start and push/PR sync reminders. If Kestral needs
authentication: in the **app**, open **Plugins → Kestral**, click the **MCP servers** gear icon, find **Kestral** under
**From plugins**, and click **Authenticate**; in the **CLI**, run `codex mcp login Kestral`. Then start a new thread
using `/new` and run `$kestral-setup` — the thread where you logged in will not see Kestral tools.

### Cursor

Paste the install prompt above (fill `--app cursor`), or use this terminal fallback:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app cursor --with-hooks
```

Open **Settings → Tools & MCPs** and click **Connect** on **Kestral** if authentication is required. Then run
`kestral-setup` to connect and start your first plan. Skills are available in this session after install — no restart.

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

Current release: **v0.4.39**

## Links

- [Kestral app](https://app.kestral.ai)
- [Full plugin documentation](./docs/README.md)
