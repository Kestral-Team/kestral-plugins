# Manifest Copy Spec

Source of truth for user-facing chat output in the `kestral-setup` and `plan` skills. Skills MUST render manifests, edit grammar,
and error messages exactly as specified here.

## Connected-source offer copy

Used by `kestral-setup` (step 2 opener and step 3a). The plugin can enrich a project with context from MCP connectors the user
has already set up in this session. Tasks come from Linear, Jira, and others; **linkable document sources are Notion,
Google Drive, Slack, and Confluence** (other connectors' URLs aren't recognized by `link_external_document`). The offer
is **reactive, not a per-source yes/no interrogation** — pick the lightest touch that fits the conversation.

### Step 2 opener (frames value + plants the connector seed)

```
I'll turn a folder of docs into a Kestral project — with an AI Project Brain (a summary Kestral generates from your
docs) and imported tasks. I can also pull in context from tools you've already connected here (Slack, Notion, Google
Drive, Linear, Jira, and others) to make the project more complete. Which folder should I scan? (Or list specific file
paths — and mention any connected source you'd like included.)
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

## Manifest format

### Small folder (≤ 15 eligible files, all included)

```
Project: <title>
Description: <first ~120 chars of description>

Documents (N total, ~<total KB> KB):
  • README.md                       (4.2 KB)   [local]
  • docs/architecture.md            (8.1 KB)   [local]
  • Q4 planning notes               (linked)   [notion]

Tasks (M total):
  • Ship onboarding plugin                     [linear]
  • Fix typo in README                          [github]

Approve, edit, or cancel?
```

### Large folder (> 15 eligible files, selection applied)

```
Project: <title>
Description: <first ~120 chars of description>

Documents (15 of 342 found, ~480 KB):
  • README.md                         (12.1 KB)  [local]
  • docs/architecture.md              (24.3 KB)  [local]
  • docs/api-reference.md             (18.7 KB)  [local]
  • docs/getting-started.md           (8.4 KB)   [local]
  • docs/deployment.md                (15.2 KB)  [local]
  • docs/design/system-overview.md    (11.0 KB)  [local]
  • docs/guides/contributing.md       (9.1 KB)   [local]
  • docs/guides/testing.md            (7.3 KB)   [local]
  • docs/security/threat-model.md     (14.8 KB)  [local]
  • docs/ops/runbook.md               (6.5 KB)   [local]
  • docs/product/roadmap.md           (5.2 KB)   [local]
  • docs/product/personas.md          (4.9 KB)   [local]
  • docs/api/endpoints.md             (16.4 KB)  [local]
  • docs/api/webhooks.md              (10.2 KB)  [local]
  • docs/faq.md                       (3.7 KB)   [local]

Dropped:
  • CHANGELOG.md                      (45.0 KB)  [local]
  • docs/internal/team-processes.md   (6.2 KB)   [local]
  • docs/legacy/v1-migration.md       (3.8 KB)   [local]

Tasks (42 total):
  • Fix login redirect loop                      [linear]
  • Add dark mode toggle                         [linear]
  • Upgrade auth library                         [linear]
  • … and 39 more

327 more files not included.
Use 'add <path>' to include specific files, 'remove <path>' to drop.

Approve, edit, or cancel?
```

### Rules

| Rule               | Detail                                                                                                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Source labels**  | Every item has a source label in brackets: `[local]` for local files, `[<mcp-namespace>]` for MCP-sourced docs/tasks. Never silently omit the label.                                                               |
| **Sizes**          | Byte sizes shown for local files in parentheses (e.g. `(4.2 KB)`). MCP-sourced docs are linked, not uploaded, so they show `(linked)` instead of a size and do **not** count toward the 500 KB budget — only local files do. |
| **Truncation**     | Documents: if > 50 items, show the first 50 then `… and N more`. Tasks: show up to 10 titles, then `… and N more` (task lists are noisier so the display limit is tighter).                                        |
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
| `look at <folder> instead` or `change folder <path>` | Re-scan a new folder — resets title, description, document list, and tasks         |
| `approve` / `yes` / `go`                             | Proceed to upload                                                                  |
| `cancel` / `no`                                      | Exit cleanly — no Kestral API calls                                                |

**Precedence:** `change folder` / `look at <folder> instead` wipes prior edits and re-derives everything from the new
scan. Other edits stack on the latest scan.

**Budget feedback on `add`:** Before appending, check whether total `byteSize` would exceed 500 KB. If so, warn
immediately. If 15 files are already selected, warn the user to `remove` one first.

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

Every error the `kestral-setup` skill can encounter has a prescribed user-facing message. Use these exact wordings.

| Failure                                           | Plugin says                                                                                                                                    |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Node missing or version < 20 (preflight)          | See **Node too old / missing** block below.                                                                                                    |
| Kestral MCP tools not in session (preflight)      | See **MCP not connected** block below.                                                                                                         |
| Auth fails / token invalid                        | "I couldn't authenticate you with Kestral. Run `/kestral:kestral-setup` to retry."                                                                      |
| Folder doesn't exist                              | "I couldn't find `<path>`. Try another folder or file set."                                                                                    |
| No documents at all (after local scan + connected sources) | "I didn't find any documents to upload — no eligible local files in `<path>` and no connected document sources available. Point me somewhere else?"  |
| Task MCP listing error                            | "I couldn't read tasks from `<source>` — skipping. Other sources still imported."                                                              |
| Per-task translation failure                      | "Skipped `<title>` from `<source>` — couldn't map to a Kestral task."                                                                          |
| Per-task upload failure                           | "Skipped `<title>` on upload — see report below."                                                                                              |
| Doc upload fails (atomic create)                  | "Upload failed. No project or documents were saved — run `/kestral:kestral-setup` again."                                                               |
| Doc upload fails (project already created)        | "Upload failed — no documents were saved. The project is at `<url>` — you can add files manually, or delete it and run `/kestral:kestral-setup` again." |
| Brain trigger: `feature-flag-disabled`            | "Project created. Project Brain isn't enabled for this workspace — ask your admin to turn it on, then open `<url>` and click 'Generate'."      |
| Brain trigger: `system-error`                     | "Project created. Brain generation couldn't start (ref `<supportRef>`). Open `<url>` and click 'Generate' to retry."                           |
| Task upload total fail                            | "Project + docs uploaded. Task import failed — you can retry from the project page."                                                           |
| Doc MCP listing error                             | "I couldn't list documents from `<source>` — skipping. Other sources still included."                                                          |
| Other mid-flow                                    | "Something went wrong. Run `/kestral:kestral-setup` again."                                                                                             |

### Partial-success rule

If the upload phase partially succeeded (project + docs landed, but tasks failed or brain couldn't start), **ALWAYS**
return the project URL alongside the error message. Users need to know where the partial work lives.

Example:

> Your project is ready: **\<url\>**
>
> Project + docs uploaded. Task import failed — you can retry from the project page.

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
