# Manifest Copy Spec

Source of truth for user-facing chat output in the `kestral-setup` and `plan` skills. Skills should follow these
patterns closely while preserving source-specific details and user-provided names.

## Connected-source offer copy

Used by `kestral-setup` (step 2 opener and source discovery). The plugin can organize connected tool context and
optionally local files into one or more Kestral projects. Tasks come from Linear, Jira, GitHub, and others; **linkable
document sources are Notion, Google Drive, Slack, and Confluence** (other connectors' URLs aren't recognized by
`link_external_document`). The offer is **reactive, not a per-source yes/no interrogation** — pick the lightest touch
that fits the conversation.

### Step 2 opener (connected sources first; local files optional)

Lead with **what they'll get**, then ask for sources. Use conversational prose, not card grids or form layouts.

**Value framing (required before asking for sources):**

```
What you'll get: A Kestral project with a Project Brain — a living, AI-generated summary of your work that:

- Gives you prioritized context when you start your day
- Gives your coding agents the same shared understanding (via Kestral MCP)
- Keeps your team aligned without status meetings — the brain updates as tasks, docs, and progress change

The apps and docs you point me at feed that brain. I'll create a Kestral project, import the most relevant tasks and
documents, and generate a Project Brain you can work from immediately.
```

**Source ask (conversational prose only):**

```
Welcome to Kestral. I'll help you set up a Kestral project with a Project Brain — a living summary of your work that
you, your coding agents, and your team can work from immediately. It stays in sync as tasks, docs, and progress change.

Where does your context live? The sources you name become the project's foundation and feed the brain. For example: a
Linear project, Jira board, Notion or Google Drive docs, Confluence pages, Slack threads, Granola notes, local
files/folders, or describe a goal.

Example: "Use my Linear Auth project and matching Drive docs" or "I'm launching billing automation — pull Jira and Notion."
```

### Step 1.5 opener (existing projects)

When the workspace already has projects, run a **prioritized work snapshot** before showing options:

1. `get_daily_brief` — 2–4 bullets on what changed, what's urgent, what needs attention.
2. `entity_lookup({ type: "project_brain", id })` for top 2–3 projects (from brief priority, else most recently
   updated).
   - 2–3 bullets per brain; note if building or missing.

Then render:

```
I found [N] Kestral projects in your workspace, each with a Project Brain that stays in sync as you and your agents
work.

Your prioritized work

[2–4 bullets from daily brief]

From your Project Brains

1. [Project Name](url)
   - [2–3 bullets from brain: goals, blockers, recent changes]
2. ...
…and [N] more projects.

You can get started right now:
- Pick a task from above and start working — I can set it in progress and help here
- Plan your day — run /kestral:plan-day (or $kestral-plan-day in Codex) for a prioritized plan

Or set up more:
- Add more context to a project — pull new docs or tasks from connected apps and refresh the brain
- Create a new project — set up a Kestral project with a brain from Linear, Jira, Notion, Drive, Granola, or other apps
```

Do not ask for sources until the user picks add-context or create-new.

After explore + plan-day, mention these ongoing skills (do not auto-run):

- Plan day: /kestral:plan-day or $kestral-plan-day
- Kestral Sync: enable hooks once (kestral-sync/README.md) — then updates on push without repeating sync
- End day review: /kestral:end-day-review or $kestral-end-day-review — reconciles done work and updates task status

```
**Prefer instead** — lead with the Project Brain value prop, ask in conversational prose, and mention connected tools
before local files. If the user wants local files, they'll say so.

### Surfacing connected sources (step 3a)

Choose one, in priority order:

| Situation                                                     | What to say                                                                                                                   |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| User already named sources ("pull my Linear too")             | Act on exactly those — no offer copy, no re-asking.                                                                            |
| Scanned content references a connected source                 | Lead with one specific line: "Your README references Linear — want me to pull the linked issues in too?"                       |
| Sources connected but neither of the above                    | One soft mention, then move on: "You also have Notion and Google Drive connected — say the word if you'd like any pulled in." |
| No relevant sources connected                                 | Say nothing about their absence.                                                                                              |

Offer sources reactively — mention what's connected once, then move on. The user can request sources now, at the
manifest checkpoint, or not at all.

## Setup manifest format

### Recommended setup
```

Recommended setup:

I found 6 possible workstreams. I recommend starting with these 3 because they have the clearest active work and
supporting context.

1. Project Brain Onboarding Why: Linear project "Project Brain", recent GitHub PRs, and matching setup docs. Tasks: 12
   selected [linear], 43 more matching. Files to upload: 5 [local] Documents to link: 3 [google_drive] Confidence: high.

2. MCP Plugin Reliability Why: GitHub issues and Linear tasks repeatedly reference MCP install failures. Tasks: 7
   selected [github, linear], 19 more matching. Files to upload: 4 [local] Confidence: high.

3. Marketing Launch Why: Recent docs and tasks mention launch copy, Hacker News, and blog posts. Tasks: 5 selected
   [linear]. Documents to link: 6 [notion, google_drive]. Confidence: medium.

Additional candidates: 3.

Ready to create these projects? Say "create these" to proceed, or tell me how you'd like them grouped differently — I
can split, merge, rename projects, or add and remove items before creating anything.

```
### Expanded project detail

Use this when the user needs to inspect selected items before approval:
```

Proposed projects

1. Billing Automation Description: Consolidates active billing workflow work and supporting implementation docs.
   Rationale: Linear project, recent GitHub issues, and matching Drive design docs. Tasks:
   - Fix invoice retry state [linear, high]
   - Add webhook replay tests [github, medium] Files to upload:
   - billing-architecture.md [local, 4.2 KB] Documents to link:
   - Billing rollout notes [google_drive] Coverage: 2 tasks selected, 43 more matching. Confidence: High. Ambiguity: one
     Slack thread may belong to Support Ops.

Skipped

- quarterly-review.pptx — unsupported file type (.pptx)

Extra candidates to revisit later

- Legacy billing cleanup: stale tasks and low recent activity.

This is a curated first pass. I'll import the most relevant context now and leave the rest available to add later.

Ready to create these projects? Say "create these" to proceed, or tell me how you'd like them grouped differently — I
can split, merge, rename projects, or add and remove items before creating anything.

```
### Rules

| Rule               | Detail                                                                                                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Source labels**  | Every item has a source label in brackets: `[local]` for local files, `[<mcp-namespace>]` for MCP-sourced docs/tasks. Never silently omit the label.                                                               |
| **Sizes**          | Byte sizes may be shown for local files in detailed item lists (e.g. `(4.2 KB)`). MCP-sourced docs are linked, not uploaded, so they show `(linked)` instead of a size.                                             |
| **Curated default** | The manifest is a recommended first pass, not a hard import cap. If the user asks for more or all matching context, expand the approved project's import in batches.                                              |
| **Truncation**     | Documents: if a detailed list is long, show the first 50 then `... and N more`. Tasks: show up to 10 titles, then `... and N more` (task lists are noisier so the display limit is tighter).                       |
| **Tasks grouping** | Group by source if multiple sources detected. Show priority label only when non-zero (e.g. `[linear, high]`).                                                                                                      |
| **Document categories** | Separate documents by action: **Files to upload** (local files uploaded as-is), **Documents to link** (external sources), **Documents to summarize** (agent-created summaries). Only show categories that have items — do not render empty sections. |
| **Skipped**        | Show skipped files with a reason (unsupported file type, excluded directory, outside scan scope, too large) under a **Skipped** section after the project list. Only show when there are skipped items.               |

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
| `look at <folder> instead` or `change folder <path>` | Switch to a different local folder and remap the proposed taxonomy                               |
| `ok` / `yes` / `go` / `create these`                   | Proceed to upload                                                                  |
| `revise`                                               | Edit the manifest before proceeding (same as edit commands below)                  |
| `cancel` / `no`                                        | Exit cleanly — no Kestral API calls                                                |

**Precedence:** user-provided buckets and explicit rename/split/merge commands override inferred taxonomy. `change
folder` / `look at <folder> instead` refreshes local-file evidence and remaps the proposed projects. Other edits stack
on the latest manifest.

**Bulk import confirmation:** Ask for explicit confirmation when the user requests a large bulk import or more than 5
projects. Summarize scope, then ask: "Okay to proceed? ok/revise/cancel" — for example: "This will import 437 tasks and
82 documents into 3 projects. Okay to proceed? ok/revise/cancel"

Re-render the manifest after each edit. On permission-aware hosts, proceed to writes after rendering unless the user
edits or cancels — do not loop waiting for explicit manifest approval. On hosts without per-tool permission prompts,
loop until the user replies ok or cancel.

## Error message conventions

Every error the `kestral-setup` skill can encounter should follow the same user-facing principles. Use these principles
and adapt project counts, source names, item counts, and URLs to the actual run.

| Situation | Message principle |
| --- | --- |
| Kestral MCP tools not in session (preflight) | See **MCP not connected** block below. |
| Auth fails / token invalid | Stop before any Kestral calls. Guide the user through their host's UI to authenticate (the agent cannot handle OAuth callbacks or generate auth links). **Claude Cowork:** Customize → Kestral → Connectors → Install → Add. **Claude Code CLI:** `/mcp` → reconnect Kestral. **Codex:** Settings → MCP Servers → Kestral → Authenticate, then new thread. **Cursor:** Settings → MCP Servers → Kestral → Authenticate (or agent calls `mcp_auth`). |
| Required core MCP tool is disconnected or missing | Stop before writes only if core tools (`whoami`, `create_project`) are missing. Missing `upload_request_urls` limits local file handling but does not block project creation, task import, or external doc linking. |
| Local folder or explicit file path doesn't exist | Do not write anything. Say you could not find `<path>` and ask for another folder, file set, connected tool, or user-provided description. |
| No usable connected sources or local files remain | Do not write anything. Explain that no importable documents or task signals were found from the selected sources and ask for another source or user-provided buckets. |
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
>
> **Next:** Once the brain finishes (~30s–2min), say "brain's ready" and I'll pull blockers and next steps so you can
> pick one and start work here.

### Post-create: Start from Project Brain

After any successful create/enrich with brain triggered, always end with a get-started prompt — do not stop at import
summary alone.
```

Your Kestral project is created and the Project Brain is generating — usually ready in 30 seconds to 2 minutes.
[Project Name](url)

Once it's ready, I'll pull blockers and next steps here so you can pick one and get started. Say "brain's ready" or
"what should I work on?" — or ask me to check in a moment.

From your Project Brain — here's what to tackle:

- [blocker or next step]
- ...

You can start right now: pick one and I can set it in progress and help here. Or: run /kestral:plan-day for a full
prioritized plan across your projects.

```
If brain is still building, offer to retry on "brain's ready". If no brain content yet, fall back to open tasks on the
project and still ask which to start.

### Pending external links

A linked external doc (`link_external_document`) returns `resolutionStatus: "pending"` when Kestral stored the agent's
`content` snapshot but the matching integration isn't connected, so it can't keep the doc in sync. This is a **partial
success** — the doc is linked, just not live. Nudge the user once, naming the distinct pending sources:

> I linked your Notion and Google Drive docs from a saved snapshot. Connect those integrations in Kestral
> (**Workspace Settings → Integrations**) and they'll autosync to the latest version.

Only Notion and Google Drive support this pending path. Slack and Confluence links require their integration to already
be connected (they error rather than storing a snapshot).

### MCP not connected

Use when Kestral MCP tools are absent in the session. Pick host-specific bullets; omit the rest.

> I can't see any Kestral MCP tools in this session yet, so I can't start setup.
>
> **All hosts:** Run `/mcp` (or your app's MCP settings) and confirm a **Kestral** server is connected
> with tools like `whoami` and `create_project`. The setup skill alone is not enough — the MCP server must be
> running in this thread.
>
> **Claude Cowork:**
> - Open **Customize → Connectors** and confirm **Kestral** is listed and enabled.
> - If Kestral is listed as "Not connected", click **Connect** and follow the instructions in the web page.
> - Fully quit and restart Cowork if the plugin was just installed.
> - Start a **new task** and run `/kestral-setup` again.
>
> **Codex:**
> - Fully quit and restart Codex after installing the plugin.
> - In **Settings → MCP Servers**, look for **Kestral** under "**From plugins**".
> - Once reconnected, run `$kestral-setup` in a **new thread** (MCP connections are locked at thread start).
>
> **Claude Code:**
> - Run `/mcp` and reconnect the **kestral** server if it shows disconnected.
> - Fully restart Claude Code if the plugin was just installed.
> - Once Kestral tools appear, run `/kestral-setup` again.
>
> **Cursor:**
> - Open **Cursor Settings → Tools & MCPs** and confirm **Kestral** is listed.
> - If the server shows **Needs authentication**, click **Connect** and follow the OAuth instructions in browser.
> - If that fails, remove and re-add the server with URL `https://app.kestral.ai/mcp`.
> - Once the server is authenticated and Kestral tools appear, run `/kestral-setup` again.
>
> **VSCode:**
> - Open the command palette (Cmd+Shift+P) and select **MCP: List Servers**. Confirm **Kestral** is listed.
> - If the server is not running, select **Kestral** then **Start Server**.
> - Follow the prompts to authenticate in the browser.
> - Once the server is **Running** and kestral tools appear, run `/kestral-setup` again.
```
