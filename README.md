# Kestral Plugin

[Kestral](https://app.kestral.ai) is an AI-powered project management tool for teams. It stores your
projects, tasks, documents, and customer feedback, and gives an AI agent context about all of it.

This plugin connects Claude Code and Codex CLI to your Kestral workspace so you can manage projects and
tasks without leaving the terminal.

## What you can do

| Command | What it does |
| --- | --- |
| `/kestral:init` | Onboard a project from a folder of docs. Scans files, imports tasks from Linear/Jira/GitHub, and creates a Kestral project. |
| `/kestral:tasks` | Search, view, and update tasks. Filter by status, priority, project, or assignee. |
| `/kestral:context` | Pull documents, projects, and tasks into the conversation so the agent can answer questions with real workspace data. |
| `/kestral:plan` | Describe a goal, review a draft project with tasks, and create it in Kestral with one approval. |

Run `/kestral:init` first to authenticate and create your first project.

## Install

### Claude Code

```bash
/plugin marketplace add Kestral-Team/kestral-plugins
/plugin install kestral@kestral-plugins
```

### Codex CLI

```bash
codex plugin marketplace add Kestral-Team/kestral-plugins
codex plugin install kestral@kestral-plugins
```

## Version

Current release: **v0.2.0**

## Links

- [Kestral app](https://app.kestral.ai)
- [Full plugin documentation](./kestral/README.md)
