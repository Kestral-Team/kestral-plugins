---
description: Authenticate and onboard a folder into a new Kestral project with documents, brain, and tasks
disable-model-invocation: true
---

# Init

Authenticate with Kestral (if needed) and onboard a local folder into a new project with documents, brain generation,
and task import from connected task MCPs.

## Prerequisites

- The Kestral MCP server must be configured in `.mcp.json` (already set up by the plugin).
- The `kestral` MCP server must show as **connected** in Claude Code (`/mcp`).
- If MCP is **disconnected**: run `/mcp` and check the `kestral` server status. If it shows an error, the server may be
  down or the URL in `.mcp.json` may be wrong for this environment. After fixing it, **fully quit and restart** Claude
  Code so it reconnects. All Kestral actions go through MCP tools — the plugin never shells out to `curl`.

## Workflow

### 1. Open with a welcome — no tool call, no approval needed

The moment `/kestral:init` runs, your **first output is the welcome message** — do not call any tool first. Everything
the welcome needs (which sources are connected) is visible from the session's loaded MCP tools, so nothing has to be
approved before you can greet the user.

Authentication is automatic and lazy: the first real tool call later in the flow (listing a connector, creating the
project) triggers the MCP client's OAuth browser login if needed, and tokens refresh silently afterward. **Do not call
`kestral_whoami` — or any tool — just to check auth.** It only adds an approval prompt without changing anything. If any
later tool call returns a 401, tell the user to reconnect the MCP server.

**Detect connected sources** by inspecting the available MCP tools (no call required):

- **Document sources** — tools whose name or description mentions `document`, `note`, `page`, `file`, or known sources
  (Granola, Notion, Google Drive, Confluence, Slack).
- **Task sources** — tools matching the patterns in `scan-tasks/SKILL.md` (Linear, Jira, GitHub Issues, Asana, etc.).

Build two lists: `detectedDocSources` and `detectedTaskSources` — referenced in the welcome message below.

**Write the welcome message.** Tailor it to what you found — be specific, not generic. Use this structure:

---

> **Welcome to Kestral** — let's get your project set up.
>
> A Kestral project gives you a single place to see what's going on: an AI **Project Brain** that surfaces your
> blockers and next steps, and project artifacts (docs and tasks) that **stay in sync automatically** as work moves.
>
> Here's what we'll do:
> - **Pull in your docs** — from a local folder and any connected tools, picking the most relevant.
> - **Build a Project Brain** — an AI read of the project's status, blockers, and next steps (~1–2 min after upload).
> - **Bring in your tasks** — import open and recently-closed tasks, and I can create new ones in Kestral too.
>
> **If sources are connected** — one brief inline line (not a bullet per source), e.g.:
> **Connected and ready to pull from:** Linear (tasks), Notion & Google Drive (docs), Granola (notes).
>
> **If no doc or task sources are connected** — omit that line entirely and use this standalone sentence instead:
> No external tools connected yet — I'll use local files. You can connect more to Claude Code any time.
>
> **What should I pull from?**
> - **If sources are connected:** Any mix of a local folder/files (e.g. `./docs`), the connected sources above
>   (e.g. "include my Notion and Linear"), or both. Just tell me and I'll build the project from it.
> - **If no sources are connected:** Point me at a local folder or file list (e.g. `./docs`) and I'll build the
>   project from it.

---

**Rules for the welcome message:**

- Only name sources actually detected this session — never list ones that aren't connected.
- Group connected sources by kind where it reads naturally (e.g. "Notion & Google Drive (docs)"). Name each source as
  the tool identifies itself.
- **Never** show the "Connected and ready to pull from" heading when `detectedDocSources` and `detectedTaskSources`
  are both empty — use the standalone no-tools sentence from the template instead.
- If only task sources are detected, note docs will come from local files and tasks can come from [source].


### 2. Receive the source selection

Accept any combination of:

- A local folder path or comma/newline-separated list of file paths
- Named connected sources ("include my Linear", "pull Notion too", "Granola meeting notes")
- Or just connected sources with no local folder (that's fine — docs from connectors alone are enough)

Carry all expressed intent into steps 3 / 3a / 3b and act on exactly what was asked — do not re-ask about sources
already named. If the user gives no sources at all (just presses enter or says something vague), prompt once:

> "No problem — just point me at a folder, a list of files, or name a connected source and I'll get started." 

### 3. Scan the folder

**Discover files.** If a folder path was given, use `Glob` with pattern `**/*.{md,txt,doc,docx}` rooted at that folder.
If explicit files were given, validate each exists.

- If the folder doesn't exist: "I couldn't find `<path>`. Try another folder or file set."
- If no eligible files found: note the absence but **do not stop** — continue to step 3a (connected sources) first.
  Documents pulled from connected sources alone are sufficient to create a project. Only if no documents exist after
  step 3a, show: "I didn't find any documents to upload — no eligible local files in `<path>` and no connected document
  sources available. Point me somewhere else?"

**Always exclude:** hidden directories/files (paths with `/.`), `.DS_Store`, `node_modules/`, `dist/`, `build/`,
`.git/`, lockfiles, generated artifacts.

**Filter noise.** Use judgment to drop non-content files. Note what was dropped.

**Capture file sizes.** For each retained eligible file, record its byte size (via `stat` in Bash or Glob metadata).
Carry `byteSize` through the manifest so rendering and budget checks do not require re-reading files.

**Read top candidates.** If eligible local files exist, read ~5 (prefer README, docs/, architecture, overview). From
those contents, draft a **title** (short project name) and **description** (1–2 sentences). If no local files were
found, defer title/description drafting to after step 3a — derive them from MCP-sourced doc titles instead.

**Select documents to upload.**

When **more than 15** eligible files remain after filtering, apply the selection heuristic below. When **15 or fewer**,
include all eligible files (no ranking step).

> **Selection heuristic:** Imagine you are onboarding to this project. Pick the 15 files you would read first.
> Prioritize README files, architecture/design docs, API references, and top-level overview files. Deprioritize deeply
> nested files, stubs (< 200 bytes), changelogs, and generated artifacts. Use the ~5 files you already read (for
> title/description) to inform which other files are likely important — e.g. if the README references
> `docs/architecture.md`, that file is high-priority.

**Limits (when selection applies):**

- **15 documents** max
- **500 KB total content** budget — stop adding files once the running total would exceed 500 KB

`byteSize` is the on-disk size. For `.doc`/`.docx`, extracted plain text may be larger or smaller than the file — treat
the budget as approximate when those files are in the set.

Track **notable omissions**: 3–5 eligible files that almost made the cut (high rank but excluded by count or budget).
These help the user `add` files without guessing paths.

**Build document list.** For each **selected** file only, record:

- `filename` — basename
- `relativePath` — relative to scanned folder
- `byteSize` — from scan step
- `filePath` — absolute path on disk (used by `upload_document`)

Do **not** read full contents for every discovered file during scan — only the ~5 used for title/description, plus any
file the user `add`s at the checkpoint.

### 3a. Detect and offer connected sources

A project is more useful with context beyond local files. The opener (step 2) already told the user this is possible —
now act on it **reactively and flexibly**. The orchestrator (`init`) owns MCP tool enumeration because it has visibility
into the conversation's loaded tools.

1. **Detect.** Inspect available MCP tools and note what document sources are connected: tool names or descriptions
   mentioning `document`, `note`, `page`, `file`, or known sources (Granola, Notion, Google Drive, Confluence, Slack).
   Task sources (Linear, Jira, GitHub Issues, etc.) are handled in step 3b.
2. **Surface lightly — never a per-source yes/no loop.** Pick the lightest touch that fits the conversation:
   - If the user **already named sources** ("pull my Linear and Notion too"), act on exactly those — don't ask again.
   - Else if the **scanned content references a connected source** (the README mentions Linear, links to a Google Doc,
     says "see Notion", etc.), lead with that one specific offer in a single line.
   - Else, mention once what's reachable and move on — for example:
     > You also have Notion, Google Drive, and Granola connected — say the word if you'd like any pulled in, otherwise
     > I'll keep documents to local files.

   Do **not** block on an answer. The user can request sources now, at the manifest checkpoint, or not at all.
3. **Pull what the user asked for.** For each requested document source, call its listing tool with a sensible default
   filter (e.g. recently modified). Use judgment to keep it relevant — do not dump hundreds of items.
4. **Record docs.** For each included doc, record `{ title, contentText, contentLength, source }`. Use the doc title
   directly (e.g. `"Q4 Planning Notes"`) as the `title` passed to `create_document` at upload, and set `source` to the
   origin tag (e.g. `"granola"`). Set `contentLength` to the character count of `contentText` (approximate byte size).
5. **Add to manifest.** MCP-sourced docs appear in the manifest with source label `[<source>]` and approximate size
   derived from `contentLength` (e.g. `(~12.3 KB)`).

If no document sources are connected: skip silently — do not tell the user about the absence.

**Error handling:** If listing fails for a source: "I couldn't list documents from `<source>` — skipping." If local
files or other MCP sources remain, note them ("Other sources still included."). Continue with remaining sources.

### 3b. Scan tasks

Follow the `scan-tasks/SKILL.md` workflow. This detects connected task MCPs (Linear, Jira, GitHub Issues, etc.), lists
open + recently completed tasks, and translates them to the Kestral import schema.

If the user scoped sources in step 2 (e.g. "just Linear" or "no tasks, docs only"), honor that here — only scan the task
sources they want. Otherwise scan all detected task sources; the user can still `skip tasks` at the checkpoint.

Store the result: `{ tasks, warnings, sources }`. If `tasks` is empty, the manifest simply omits the Tasks section — no
user-facing message about missing task MCPs.

### 4. Render manifest

Show a human-readable manifest. Include byte sizes for every listed document.

**Small folder (≤ 15 eligible files, all included):**

```
Project: <title>
Description: <first ~120 chars of description>

Documents (N total, ~<total KB> KB):
  • README.md                       (4.2 KB)   [local]
  • docs/architecture.md            (8.1 KB)   [local]
  • Q4 planning notes               (~12.3 KB) [granola]

Tasks (X total):
  • Fix login redirect loop                    [linear, high]
  • Add dark mode toggle                        [linear, medium]

Dropped (M):
  • node_modules/...                (dependency directory)

Approve, edit, or cancel?
```

**Source labels:** Every item has a bracket label — `[local]` for local files, `[<source>]` for MCP-sourced docs/tasks.
Never silently omit the label. Local file sizes shown in parentheses; MCP-sourced docs show approximate size from
`contentLength` prefixed with `~` (e.g. `(~12.3 KB)`).

**Tasks section rules:**

- Only render if `scan-tasks` returned a non-empty `tasks` array.
- Group by source if multiple sources detected.
- Show up to 10 task titles with `[source, priority-label]` annotation.
- If more than 10 tasks, show first 10 and "`… and N more`".

**Truncation:** Documents: if > 50 items, show the first 50 then `… and N more`. Tasks use the tighter 10-item display
limit above. Both rules apply independently to each category.

**Large folder (> 15 eligible files, selection applied):**

List **all** selected files — do not truncate the selection (15 lines is short enough). Show 3–5 notable omissions and a
count of remaining excluded files:

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

Notable omissions:
  • CHANGELOG.md                      (45.0 KB)
  • docs/internal/team-processes.md   (6.2 KB)
  • docs/legacy/v1-migration.md       (3.8 KB)

Tasks (42 total):
  • Fix login redirect loop                      [linear, high]
  • Add dark mode toggle                          [linear, medium]
  • Upgrade auth library                          [linear, urgent]
  • … and 39 more

327 more files not included.
Use 'add <path>' to include specific files, 'remove <path>' to drop.

Approve, edit, or cancel?
```

List dropped noise files (e.g. `node_modules/`) under **Dropped** when relevant.

**Suggest sources to connect (light, optional, once).** Kestral can also pull from sources that aren't connected this
session. When you render the manifest, if any supported source is missing from `detectedDocSources` /
`detectedTaskSources`, append a **single soft line** under the manifest — not a question, not a new step, and never
something that blocks approval:

> 💡 Want richer projects next time? You could also connect <up to 3 unconnected sources> to Claude Code — e.g. Jira
> issues or Confluence pages flow straight in.

Draw from the sources Kestral supports — tasks: Linear, Jira, GitHub, Asana; documents: Notion, Google Drive, Confluence,
Granola, Slack — excluding anything already detected. Show it at most once (with the first manifest render), skip it
entirely if everything relevant is already connected, and never let it delay the `Approve, edit, or cancel?` prompt.

### 5. Manifest checkpoint

Wait for user input. Supported commands:

| Command                                            | Effect                                                                                              |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **approve** / **yes** / **go**                     | Proceed to upload                                                                                   |
| **cancel** / **no**                                | Exit cleanly — no Kestral API calls                                                                 |
| **remove** `<path>`                                | Remove a file from the document list                                                                |
| **remove** `<source>` **documents**                | Bulk-remove all documents from a specific source (e.g. `remove granola documents`)                  |
| **add** `<path>`                                   | Validate path, `stat` for `byteSize`, append metadata only (do not read file contents until upload) |
| **skip tasks**                                     | Remove the Tasks section — no tasks will be imported                                                |
| **change title** / **title:** `<new title>`        | Override project title                                                                              |
| **change description** / **description:** `<text>` | Override project description                                                                        |
| **look at** `<folder>` **instead**                 | Alias for `change folder` — re-scan a new folder                                                    |
| **change folder** `<path>`                         | Re-scan a new folder — **resets** title, description, document list, and tasks                      |

**Budget feedback on `add`:** Before appending, `stat` the file and check whether total selected `byteSize` would exceed
**500 KB**. If so, warn immediately:

> Adding `big-spec.md` (120 KB) would bring the total to 580 KB, which risks exceeding Claude's context window during
> upload. Consider removing a large file first, or approve and I'll upload what fits.

If the user already has **15** selected files, warn that they should `remove` one before adding unless they explicitly
want to exceed the doc cap.

**Precedence:** `change folder` wipes prior edits and re-derives everything from the new scan. Other edits stack on the
latest scan until `change folder` runs.

Re-render the manifest after each edit. Loop until the user approves or cancels.

### 6. Upload

On approve:

**Content budget check.** Sum `byteSize` (local docs) and `contentLength` (MCP docs) from the manifest. If **> 500 KB**,
warn the user and proceed only if they confirm.


**Create the project** — call `kestral_create_project` with `{ title, description }`. Store `projectId` and `url`.

**Add documents** — add each manifest document to the project with the tool that matches its source. Documents and
projects are orthogonal: every tool takes an optional `projectId`, and here you always pass the project you just created.

- **Local files** — call `upload_document` once per file with `{ filePath, projectId }`. The local MCP bridge reads
  the file and streams the bytes directly to storage via a presigned URL — they never pass through the agent —
  so it works for any file type and any size. Use absolute paths only; the bridge rejects sensitive locations
  (`.ssh`, `.aws`, `.kestral`, `.env`, etc.).
- **MCP-sourced documents** — call `create_document` once per doc with `{ title, content, projectId, source }`, where
  `content` is the text you fetched from the source MCP and `source` is the origin tag (e.g. `"granola"`, `"notion"`).
  The server stores it under `metadata.claudeCodePlugin.source`.

Each call returns a single document `{ documentId, title, url }`. Track successes and failures across all calls:

- If some documents failed, report which ones and why.
- If all failed: "Upload failed — no documents were saved. The project is at `<url>` — you can add files manually, or
  delete it and run `/kestral:init` again."

On 401 from any tool, tell the user to reconnect the MCP server to re-authenticate, then retry.

**Trigger brain generation** — call `kestral_trigger_project_brain_build` with `{ projectId }`. Capture the response (do
not fail the overall flow on error). Three response cases:

| Response                                           | User-facing message                                                                                                                       |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `enqueued: true`                                   | "Brain is generating — usually 1–2 minutes."                                                                                              |
| `enqueued: false, reason: 'feature-flag-disabled'` | "Project created. Project Brain isn't enabled for this workspace — ask your admin to turn it on, then open `<url>` and click 'Generate'." |
| `enqueued: false, reason: 'system-error'`          | "Project created. Brain generation couldn't start (ref `<supportRef>`). Open `<url>` and click 'Generate' to retry."                      |

**Import tasks** — if the manifest includes tasks (non-empty `tasks` array from `scan-tasks`), call
`kestral_create_project_tasks` with `{ projectId, tasks }`. Capture `created` and `failed` from the response. Do not
fail the overall flow if some tasks fail.

- Per-task translation failure: "Skipped `<title>` from `<source>` — couldn't map to a Kestral task."
- Per-task upload failure: "Skipped `<title>` on upload — see report below."
- All tasks failed: "Project + docs uploaded. Task import failed — you can retry from the project page."

**Present results:**

**Partial-success rule:** If the upload phase partially succeeded (project + docs landed, but tasks failed or brain
couldn't start), **ALWAYS** return the project URL alongside the error message. Users need to know where the partial
work lives.

> Your project is ready: **\<url\>**
>
> \<brain message from table above\>
>
> \<task summary — only if tasks were attempted\>

Task summary format:

- All succeeded: "Imported X tasks from \<source\>."
- Some failed: "Imported X tasks from \<source\>; Y could not be imported."
- All failed: "Project + docs uploaded. Task import failed — you can retry from the project page."

### 7. Encourage next steps

Don't stop at the link. Close with a short nudge toward the Project Brain and a small menu of follow-ups — invite, don't
lecture. Skip this section if the project wasn't created.

**Point them at the brain (for blockers).** The Project Brain finishes generating ~1–2 minutes after upload and surfaces
the project's status, **blockers**, and suggested next steps. Encourage the user to open it (only when the brain was
enqueued — i.e. `enqueued: true`):

> Once the brain finishes (~1–2 min), open **\<url\>** to see your project's status, blockers, and suggested next steps —
> it's the fastest way to spot what's in your way.

**Offer follow-up actions.** Present these as options the user can choose — do not auto-run any:

> Want me to keep going? I can:
> • **Add more context** — point me at meeting notes, a Notion/Granola/Drive doc, or recent work and I'll add it to this
>   project and refresh the brain.
> • **Help clear blockers** — once the brain flags blockers, tell me and I'll pull those tasks up so we can work them.
> • **Loop in your team** — teammates need to be in your Kestral workspace to see this. Invite them in Kestral under
>   **Workspace Settings → Members**, then they'll have access — especially worth it if a blocker depends on someone else.

When the user picks one, map it to the right tools:

| User picks        | Do this                                                                                                                                                                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Add more context  | Treat the new files/sources like steps 3 / 3a (scan locally or pull from a connector), then add them to the **existing** `projectId` (`upload_document` for local files, `create_document` for MCP-sourced docs), and re-run `kestral_trigger_project_brain_build` to refresh the brain. |
| Help clear blockers | Hand off to `tasks/SKILL.md`. Use `search_tasks({ projectId })` to list this project's open tasks and let the user pick which to work on next.                                                                                          |
| Loop in team      | Sharing the URL alone won't grant access — teammates must be members of the workspace. Tell the user to invite them in Kestral under **Workspace Settings → Members**; there's no MCP tool to invite from the plugin.                       |

> **Note:** The plugin can only *link* to the brain today — no MCP tool returns the brain's blocker/next-step content, so
> the skill can't read individual blockers inline or say who one is assigned to. Rely on the user opening the link and
> telling you what they want to tackle.

## Cancel behavior

On cancel, confirm:

> Cancelled. No changes were made in Kestral.

Do not call any write MCP tools.

## Error message reference

See `docs/manifest-copy-spec.md` for the full error message table. All error messages in this skill MUST match the exact
wording specified there.
