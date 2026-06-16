# Kestral Plugin

[Kestral](https://app.kestral.ai) is an AI-powered project management tool for teams. It stores your
projects, tasks, documents, and customer feedback, and gives an AI agent context about all of it.

This plugin connects Claude Code and Codex CLI to your Kestral workspace so you can manage projects and
tasks without leaving the terminal.

## What you can do

| Command | What it does |
| --- | --- |
| `/kestral:kestral-setup` | Onboard a project from a folder of docs. Scans files, imports tasks from Linear/Jira/GitHub, and creates a Kestral project. |
| `/kestral:tasks` | Search, view, and update tasks. Filter by status, priority, project, or assignee. |
| `/kestral:context` | Pull documents, projects, and tasks into the conversation so the agent can answer questions with real workspace data. |
| `/kestral:plan` | Describe a goal, review a draft project with tasks, and create it in Kestral with one approval. |
| `/kestral:plan-day` | Turn your Kestral daily brief and calendar into a ranked plan for today. |
| `/kestral:end-day-review` | Summarize today, reconcile project updates, and prioritize tomorrow. |

In Claude Code, run `/kestral:kestral-setup` first to authenticate and create your first project.
In Codex, type `@kestral` to target the plugin, or invoke a bundled skill directly with `$kestral-setup`, `$kestral-plan-day`, or `$kestral-end-day-review` (not `/kestral:…` slash commands). The Codex marketplace installs Kestral by default; use `/plugins` to confirm it is enabled.

## Install

**Quick install (macOS):** one command connects to Kestral at `https://app.kestral.ai/mcp` and installs to **Claude Code,
Claude Desktop, and Codex** (all detected apps). Prerequisites: **git** (and **Ruby** for Claude Desktop — included with
macOS).

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
```

Non-interactive examples:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-code
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app claude-desktop
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --app codex
```

**Note:** The script registers the Kestral marketplace via the `claude`/`codex` CLI, and for Claude Desktop writes
directly to Cowork's plugin files under `~/Library/Application Support/Claude/`.
[View the script source](https://github.com/Kestral-Team/kestral-plugins/blob/main/setup.sh) before running.

### Advanced: local file upload (macOS only)

If you need to upload many files from your computer, pass `--go-mcp` to install a small local helper at
`~/.kestral/bin/kestral-mcp`:

```bash
curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --go-mcp
```

### Claude Code (manual)

```bash
/plugin marketplace add Kestral-Team/kestral-plugins
/plugin install kestral@kestral-plugins
```

### Codex CLI

```bash
codex plugin marketplace add Kestral-Team/kestral-plugins
```

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

Current release: **v0.4.21**

## Links

- [Kestral app](https://app.kestral.ai)
- [Full plugin documentation](./docs/README.md)
