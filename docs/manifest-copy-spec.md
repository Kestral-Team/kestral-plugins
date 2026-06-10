# Manifest Copy Spec

Source of truth for user-facing chat output in the `kestral-setup` and `plan` skills. Skills should follow these
patterns closely while preserving source-specific details and user-provided names.

## Connected-source offer copy

Used by `kestral-setup` (step 2 opener and source discovery). The plugin can organize local files and connected tool
context into one or more Kestral projects. Tasks come from Linear, Jira, GitHub, and others; **linkable document sources
are Notion, Google Drive, Slack, and Confluence** (other connectors' URLs aren't recognized by
`link_external_document`). The offer is **reactive, not a per-source yes/no interrogation** — pick the lightest touch
that fits the conversation.

### Step 2 opener (frames value + plants the connector seed)

```
Welcome to Kestral. I can help turn scattered files, tasks, and connected tool data into organized Kestral projects so
you and your team can stay on track automatically.

I can work from local files, GitHub, Linear, Jira, Notion, Google Drive, Slack, and any other connected tool available
in this chat. Give me whatever you have: a folder, a repo, a task system, a few links, or just "I'm not organized yet,"
and I'll propose a starting structure with projects, documents, tasks, and Project Brains.
```

### Surfacing connected sources (step 3a)

Choose one, in priority order:

| Situation                                                     | What to say                                                                                                                   |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| User already named sources ("pull my Linear too")             | Act on exactly those — no offer copy, no re-asking.                                                                            |
| Scanned content references a connected source                 | Lead with one specific line: "Your README references Linear — want me to pull the linked issues in too?"                       |
| Sources connected but neither of the above                    | One soft mention, then move on: "You also have Notion and Google Drive connected — say the word if you'd like any pulled in, otherwise I'll keep documents to local files." |
| No relevant sources connected                                 | Say nothing about their absence.                                                                                              |

**Rules:** Never loop a yes/no per source. Never block the flow waiting for an answer — the user can request sources now,
at the manifest checkpoint, or not at all. Whatever they include feeds the same manifest checkpoint below.

## Setup manifest format

### Recommended setup

```
Recommended setup:

I found 6 possible workstreams. I recommend starting with these 3 because they have the clearest active work and
supporting context.

1. Project Brain Onboarding
   Why: Linear project "Project Brain", recent GitHub PRs, and matching setup docs.
   Tasks: 12 selected [linear], 43 more matching.
   Documents: 8 selected [local, google_drive], 96 more candidates.
   Confidence: high.

2. MCP Plugin Reliability
   Why: GitHub issues and Linear tasks repeatedly reference MCP install failures.
   Tasks: 7 selected [github, linear], 19 more matching.
   Documents: 4 selected [local], 12 more candidates.
   Confidence: high.

3. Marketing Launch
   Why: Recent docs and tasks mention launch copy, Hacker News, and blog posts.
   Tasks: 5 selected [linear].
   Documents: 6 selected [notion, google_drive].
   Confidence: medium.

Additional candidates: 3.

Say "create these", "only create Project Brain Onboarding", "rename Marketing Launch to Launch Plan", "use these
buckets: ...", or "import all matching tasks into Project Brain Onboarding".
```

### Expanded project detail

Use this when the user needs to inspect selected items before approval:

```
Proposed projects

1. Billing Automation
   Description: Consolidates active billing workflow work and supporting implementation docs.
   Rationale: Linear project, recent GitHub issues, and matching Drive design docs.
   Selected tasks:
     - Fix invoice retry state [linear, high]
     - Add webhook replay tests [github, medium]
   Selected documents:
     - billing-architecture.md [local]
     - Billing rollout notes [google_drive, linked]
   Coverage: 2 tasks selected, 43 more matching; 2 docs selected, 96 more candidates.
   Confidence: High. Ambiguity: one Slack thread may belong to Support Ops.

Extra candidates to revisit later
- Legacy billing cleanup: stale tasks and low recent activity.

This is a curated first pass. I'll import the most relevant context now and leave the rest available to add later.

Approve, edit, or cancel?
```

### Rules

| Rule               | Detail                                                                                                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Source labels**  | Every item has a source label in brackets: `[local]` for local files, `[<mcp-namespace>]` for MCP-sourced docs/tasks. Never silently omit the label.                                                               |
| **Sizes**          | Byte sizes may be shown for local files in detailed item lists (e.g. `(4.2 KB)`). MCP-sourced docs are linked, not uploaded, so they show `(linked)` instead of a size.                                             |
| **Curated default** | The manifest is a recommended first pass, not a hard import cap. If the user asks for more or all matching context, expand the approved project's import in batches.                                              |
| **Truncation**     | Documents: if a detailed list is long, show the first 50 then `... and N more`. Tasks: show up to 10 titles, then `... and N more` (task lists are noisier so the display limit is tighter).                       |
| **Tasks grouping** | Group by source if multiple sources detected. Show priority label only when non-zero (e.g. `[linear, high]`).                                                                                                      |
| **Dropped**        | List dropped noise files (e.g. `node_modules/`) under a **Dropped** section when relevant.                                                                                                                         |

## Edit grammar

Phrases the `kestral-setup` skill must recognize at the manifest checkpoint:

| Phrase                                               | Effect                                                                             |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `remove <file>`                                      | Remove a specific file from the document list                                      |
| `add <path>`                                         | Validate path, `stat` for byte size, append to document list                       |
| `remove <source> documents`                          | Bulk-remove all documents from a specific source (e.g. `remove notion documents`) |
| `skip tasks`                                         | Remove the entire Tasks section — no tasks will be imported                        |
| `title: <new>` or `change title <new>`               | Override project title                                                             |
| `description: <new>` or `change description <new>`   | Override project description                                                       |
| `only create <project>`                              | Deselect other proposed projects                                                   |
| `skip <project>`                                     | Remove a proposed project from this run                                            |
| `rename <project> to <new title>`                    | Update a proposed project title                                                    |
| `split <project>`                                    | Ask one focused follow-up and split into clearer workstreams                       |
| `merge <project A> and <project B>`                  | Combine proposed projects and their selected context                               |
| `move <item> to <project>`                           | Move a selected task or document between proposed projects                         |
| `use these buckets: <list>`                          | Switch to user-led taxonomy and remap sources                                      |
| `import more <source> into <project>`                 | Expand import scope for that project/source                                        |
| `import all matching <tasks/documents>`              | Switch that project/source to bulk import mode                                     |
| `look at <folder> instead` or `change folder <path>` | Re-scan a new folder and remap the proposed taxonomy                               |
| `approve` / `yes` / `go`                             | Proceed to upload                                                                  |
| `cancel` / `no`                                      | Exit cleanly — no Kestral API calls                                                |

**Precedence:** user-provided buckets and explicit rename/split/merge commands override inferred taxonomy. `change
folder` / `look at <folder> instead` refreshes local-file evidence and remaps the proposed projects. Other edits stack
on the latest manifest.

**Bulk import confirmation:** Ask for explicit confirmation when the user requests a large bulk import or more than 5
projects, using one concise scope summary such as: "This will import 437 tasks and 82 documents into 3 projects.
Proceed?"

Re-render the manifest after each edit. Loop until the user approves or cancels.

## Plan manifest format

Used by the `plan` skill (`/kestral:plan`). Simpler than the kestral-setup manifest — no documents or file sizes, just a project
title/description and a numbered task list with priorities.

### New project

```
Project: Auth OIDC Migration
Description: Migrate from legacy OAuth 1.0 to OpenID Connect for all auth flows.

Tasks (8):
  1. [high]    Audit current OAuth endpoints and token formats
  2. [high]    Set up OIDC provider in staging
  3. [medium]  Write token migration script
  4. [medium]  Update login flow to use OIDC
  5. [medium]  Update API auth middleware
  6. [medium]  Write migration rollback script
  7. [low]     Update developer documentation
  8. [low]     QA full auth flow on staging

Tags: auth, migration

Approve, edit, or cancel?
```

### Adding tasks to an existing project

```
Adding tasks to: Auth Overhaul (active, 12 existing tasks)

New tasks (5):
  1. [medium]  Write token migration script
  2. [medium]  Update login flow to use OIDC
  3. [medium]  Update API auth middleware
  4. [low]     Update developer documentation
  5. [low]     QA full auth flow on staging

Approve, edit, or cancel?
```

### Plan edit grammar

Extends the shared grammar from the **Edit grammar** section above — `approve` and `cancel` work in all plan manifests.
`title:` and `description:` are only available in the **new-project** flow; the existing-project checkpoint is
tasks-only so title/description edits are disabled. Additional plan-specific phrases:

| Phrase                                | Effect                                          |
| ------------------------------------- | ----------------------------------------------- |
| `add <task title>`                    | Append a task (default priority: medium)        |
| `add <task title> [high]`             | Append a task with explicit priority            |
| `remove <number>` or `remove <title>` | Remove a task by number or title match          |
| `reorder <number> to <position>`      | Move a task to a different position             |
| `reprioritize <number> <priority>`    | Change a task's priority                        |
| `tag: <tag1>, <tag2>`                 | Set tags to apply to the project after creation |

Re-render the manifest after each edit. Loop until the user approves or cancels.

**Task count limit:** If the user `add`s beyond 15 tasks, warn: "That's a lot of tasks for one project. Consider
splitting into multiple projects, or approve and I'll create them all."

## Error message conventions

Every error the `kestral-setup` skill can encounter should follow the same user-facing principles. Use these principles
and adapt project counts, source names, item counts, and URLs to the actual run.

| Situation | Message principle |
| --- | --- |
| Node missing or version < 20 (preflight) | See **Node too old / missing** block below. |
| Kestral MCP tools not in session (preflight) | See **MCP not connected** block below. |
| Auth fails / token invalid | Stop before any writes. Tell the user Kestral authentication failed and to reconnect the Kestral MCP server before retrying setup. |
| Required MCP tool is disconnected or missing | Stop before writes. Name the missing Kestral capability and ask the user to reconnect or restart the MCP server before retrying. |
| Local folder or explicit file path doesn't exist | Do not write anything. Say you could not find `<path>` and ask for another folder, file set, repo, task system, or connected source. |
| No usable local files or connected sources remain | Do not write anything. Explain that no importable documents or task signals were found from the selected sources and ask for another source or user-provided buckets. |
| Task source listing error | Skip `<source>` and continue when other sources remain. Include `<source>` in the skipped-source summary. If no usable sources remain, ask for another source. |
| Document source listing error | Skip `<source>` and continue when other sources remain. Include `<source>` in the skipped-source summary. If no usable sources remain, ask for another source. |
| Per-task translation failure | Skip the affected task, name its source when available, and summarize skipped tasks per project/source in the final report. |
| Per-document upload/link failure | Continue with other selected documents when safe. Summarize failed documents per affected project/source in the final report. |
| Project creation fails before imports for that project | Report that no documents or tasks were imported for the affected project. Continue with other approved projects when safe. |
| Brain trigger: `feature-flag-disabled` | Treat as non-fatal. Report the affected project link(s), explain Project Brain is disabled for the workspace, and tell the user to ask an admin to enable it or generate later from each affected project page. |
| Brain trigger: `system-error` | Treat as non-fatal. Report the affected project link(s), include the support reference when available, and point the user to retry Generate from each affected project page. |
| Task import batch failure | Keep already-created projects and documents. Summarize failed task batches per affected project/source and say task import can be retried or completed from the project page. |
| Cancel before writes | Exit cleanly and say no Kestral projects, documents, or tasks were created. |
| Cancel after writes started | Stop future writes, then summarize already-created project links and completed/skipped imports. |
| Other mid-flow failure | Preserve and report any successful project links. Summarize what completed, what failed, and what source or project should be retried. |

### Partial-success rule

If any project creation, document upload/link, task import, or brain trigger partially succeeded, **always** return the
successful project links alongside the failure summary. Users need to know where the created work lives.

Example:

> Created projects:
> - Project Brain Onboarding: **\<url\>**
> - MCP Plugin Reliability: **\<url\>**
>
> Documents: Project Brain Onboarding linked 8/8 documents. MCP Plugin Reliability uploaded 3/4 local files; skipped
> `docs/legacy-notes.md` because upload failed.
>
> Tasks: Imported 12 Linear tasks into Project Brain Onboarding. GitHub task import failed for MCP Plugin Reliability;
> retry from the project page or rerun setup for that source.
>
> Brain: Generation started for Project Brain Onboarding. Brain generation could not start for MCP Plugin Reliability
> (ref `<supportRef>`); open the project and click Generate to retry.

### Pending external links

A linked external doc (`link_external_document`) returns `resolutionStatus: "pending"` when Kestral stored the agent's
`content` snapshot but the matching integration isn't connected, so it can't keep the doc in sync. This is a **partial
success** — the doc is linked, just not live. Nudge the user once, naming the distinct pending sources:

> I linked your Notion and Google Drive docs from a saved snapshot. Connect those integrations in Kestral
> (**Workspace Settings → Integrations**) and they'll autosync to the latest version.

Only Notion and Google Drive support this pending path. Slack and Confluence links require their integration to already
be connected (they error rather than storing a snapshot).

### Node too old / missing

Use when preflight step 0A finds `node`/`npx` missing or major version **< 20** (Claude Code, Claude Cowork, and
Codex — Cowork spawns the stdio bridge on the host Mac, not in the agent VM). Substitute `<version>` from
`node --version` when available, or **not installed** when the command fails. Show this message **in full** — do not
shorten it.

> I can't start Kestral setup yet. **Kestral needs Node 20 or higher** — a small free program the plugin uses in the
> background. Your computer currently has **`<version>`**.
>
> Nothing has been uploaded. Upgrade Node using either option below, then run setup again in a **new chat**.
>
> ---
>
> ### Option A — Quick upgrade (Terminal, one command)
>
> Open **Terminal** (Mac) or **PowerShell** (Windows), paste **one** line for your computer, and press Enter:
>
> **Mac** (works if you already have any version of Node, including an old one):
>
> ```
> npm install -g n && n lts
> ```
>
> **Mac** (if you use Homebrew instead):
>
> ```
> brew install node
> ```
>
> **Windows:**
>
> ```
> winget install OpenJS.NodeJS.LTS
> ```
>
> Enter your password if prompted. When it finishes, run:
>
> ```
> node --version
> ```
>
> You should see **v20** or higher (e.g. `v22.x.x`). Then **fully quit** Claude Code, Claude Cowork, or Codex, reopen
> it, and run setup again.
>
> ---
>
> ### Option B — Download from the website
>
> 1. Go to **https://nodejs.org**
> 2. Click **Download Node.js (LTS)** and run the installer (Mac: `.pkg`, Windows: `.msi` — keep the default options)
> 3. **Fully quit** Claude Code, Claude Cowork, or Codex, reopen it, and run setup again in a **new chat**
>
> ---
>
> ### Still stuck?
>
> If `node --version` still shows a number below 20, **restart your computer** and check again. You do not need to
> reinstall the Kestral plugin. In Codex, check **Settings → MCP Servers** for **Kestral** (not `node_repl`). In Claude
> Code or Cowork, run `/mcp` and confirm **kestral** is connected.

### MCP not connected

Use when Kestral MCP tools are absent but Node preflight passed (≥ 20, `npx` on PATH). Pick host-specific bullets;
omit the rest.

> I can't see any Kestral MCP tools in this session yet, so I can't start setup.
>
> **All hosts:** Run `/mcp` (or your app's MCP settings) and confirm a **Kestral** / **kestral** server is connected
> with tools like `upload_document` and `kestral_whoami`. The setup skill alone is not enough — the MCP bridge must be
> running in this thread.
>
> **Claude Cowork:**
> - Confirm Node first: `node --version` and `which npx` in Terminal (Cowork needs local Node even though other HTTP
>   connectors do not).
> - Open **Customize → Connectors** and confirm **Kestral** is listed and enabled.
> - If you saw **This plugin includes local MCP servers**, click **Continue** to register the connector.
> - Fully quit and restart Cowork, then start a **new task** and run `/kestral:kestral-setup` again.
>
> **Codex:**
> - Fully quit and restart Codex after installing the plugin.
> - In **Settings → MCP Servers**, look for **Kestral** / **kestral** — **not** `node_repl` (that is Codex's JS sandbox).
> - If only `node_repl` appears, add a manual entry in `~/.codex/config.toml` (see Node message above for the `npx`
>   path), restart, and open a new thread.
>
> **Claude Code:**
> - Run `/mcp` and reconnect the **kestral** server if it shows disconnected.
> - Fully restart Claude Code if the plugin was just installed.
>
> Once Kestral tools appear, run setup again — a browser window will open for OAuth on the first tool call.
