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

In Claude Code, run `/kestral:kestral-setup` first to authenticate and create your first project.
In Codex, type `@kestral` to target the plugin, or invoke the bundled skill directly with `$kestral-setup`.

## Install

> **Requires [Node.js](https://nodejs.org) 20+.** The plugin launches a small local bridge via `npx`
> (`@kestral/kestral-mcp`) so folder onboarding and document upload can read files from your machine. The bridge signs
> in to Kestral via OAuth (a browser opens on first use) and uploads file bytes directly to storage.

### Claude Code

```bash
/plugin marketplace add Kestral-Team/kestral-plugins
/plugin install kestral@kestral-plugins
```

### Codex CLI

```bash
codex plugin marketplace add Kestral-Team/kestral-plugins
codex plugin add kestral@kestral-plugins
```

## Version

Current release: **v0.4.4**

## Links

- [Kestral app](https://app.kestral.ai)
- [Full plugin documentation](./docs/README.md)
