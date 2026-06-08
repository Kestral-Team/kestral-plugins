---
name: kestral-setup
description: Authenticate and onboard a folder into a new Kestral project with documents, brain, and tasks. Use only when the user explicitly runs setup or asks to onboard a project.
---

# Setup

Authenticate with Kestral (if needed) and onboard a local folder into a new project with documents, brain generation,
and task import from connected task MCPs.

## Prerequisites

Kestral MCP runs locally via `npx @kestral/kestral-mcp` on the user's Mac — **Node 20+** on login PATH for **Claude Code,
Cowork, and Codex**. All Kestral actions use MCP tools only (no shell HTTP).

**Kestral** must show as **connected** with `upload_document` in the tool list — including Cowork. If missing, reconnect
in the client; do not send users to another app for local uploads.

## Workflow

### 0. Preflight

Run before any Kestral MCP call. Stop on first failure; exact messages in `docs/manifest-copy-spec.md`.

**A. Node (all hosts)** — Bash: `node --version` and `which npx`. Missing, unresolvable, or major **< 20** → show full
**Node too old / missing** message (`<version>` from output, or "not installed"). Do not blame MCP disconnect when Node
is the cause. Old-Node signature: `fs/promises ... 'constants'` from `npx -y @kestral/kestral-mcp`.

**B. Kestral tools (all hosts)** — Confirm `upload_document` / `kestral_*` in this thread (`/mcp`). No tools + Node OK →
**MCP not connected** (host-specific bullets). Codex: **Kestral** server required — `node_repl` is not the bridge.

### 1. Authenticate

Call `whoami` to confirm the Kestral MCP connection is active (OAuth opens the browser automatically on first use if
needed). If it fails, tell the user to reconnect the MCP server in client settings and retry.

### 2. Frame the run and ask for a source

Open with ~2 sentences framing what happens and what they get, then ask for the folder in the same message. For example:

> Welcome to Kestral! We're here to help you work better and faster.
> I'll turn a collection of docs into a Kestral project — with an AI **Project Brain** (a summary Kestral generates from
> your docs) and imported tasks. I can also pull in context from tools you've already connected here (Slack, Notion,
> Google Drive, Linear, Jira, and others) to make the project more complete. Which folder or files should I scan? (Or list
> specific file paths — and mention any connected source you'd like included.)

Accept either a directory path or a comma/newline-separated list of files. If the user names connected sources, carry
that intent into steps 3a/3b and act on exactly those.

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
now act on it **reactively and flexibly**. The orchestrator (`kestral-setup`) owns MCP tool enumeration because it has visibility
into the conversation's loaded tools.

1. **Detect.** Inspect available MCP tools and note what document sources are connected: tool names or descriptions
   mentioning `document`, `note`, `page`, `file`, or known **linkable** sources (Notion, Google Drive, Slack,
   Confluence). Only these can be linked into Kestral — skip docs from other connectors (e.g. Granola); their URLs
   aren't recognized by `link_external_document`. Slack and Confluence additionally require their Kestral integration
   to already be connected (no offline snapshot fallback). Task sources (Linear, Jira, GitHub Issues, etc.) are handled
   in step 3b.
2. **Surface lightly — never a per-source yes/no loop.** Pick the lightest touch that fits the conversation:
   - If the user **already named sources** ("pull my Linear and Notion too"), act on exactly those — don't ask again.
   - Else if the **scanned content references a connected source** (the README mentions Linear, links to a Google Doc,
     says "see Notion", etc.), lead with that one specific offer in a single line.
   - Else, mention once what's reachable and move on — for example:
     > You also have Notion and Google Drive connected — say the word if you'd like any pulled in, otherwise
     > I'll keep documents to local files.

   Do **not** block on an answer. The user can request sources now, at the manifest checkpoint, or not at all.
3. **Pull what the user asked for.** For each requested document source, call its listing tool with a sensible default
   filter (e.g. recently modified). Use judgment to keep it relevant — do not dump hundreds of items.
4. **Record docs.** For each included doc, record `{ filename, relativePath, sourceUrl, contentText }`. `sourceUrl` is
   the doc's **canonical URL in its source system** (the Google Drive `/edit` link, Notion page URL, etc.) — capture it
   from the listing tool's response; it is required. Derive `filename` from the doc title (e.g. `"Q4 Planning Notes"` →
   `"Q4 Planning Notes.md"`). Use `<source>/<filename>` as `relativePath` (e.g. `"notion/Q4 Planning Notes.md"`).
   These docs are **linked**, not copied: at upload they go through `link_external_document` using `sourceUrl` so
   Kestral preserves source provenance and autosyncs the doc once the matching integration is connected. `contentText`
   is kept only as a fallback snapshot passed to `link_external_document` for the case where no matching integration is
   connected yet. **Never reproduce external content through `create_document`** — that loses provenance and breaks
   autosync.
5. **Add to manifest.** MCP-sourced docs appear in the manifest with source label `[<source>]` and a `(linked)` marker
   instead of a size — their bytes live in the source system, not in the upload, so they don't count toward the budget.

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
  • Q4 planning notes               (linked)   [notion]

Tasks (X total):
  • Fix login redirect loop                    [linear, high]
  • Add dark mode toggle                        [linear, medium]

Dropped (M):
  • node_modules/...                (dependency directory)

Approve, edit, or cancel?
```

**Source labels:** Every item has a bracket label — `[local]` for local files, `[<source>]` for MCP-sourced docs/tasks.
Never silently omit the label. Local file sizes shown in parentheses; MCP-sourced (linked) docs show `(linked)` instead
of a size, since their bytes are not uploaded.

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

### 5. Manifest checkpoint

Wait for user input. Supported commands:

| Command                                            | Effect                                                                                              |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **approve** / **yes** / **go**                     | Proceed to upload                                                                                   |
| **cancel** / **no**                                | Exit cleanly — no Kestral API calls                                                                 |
| **remove** `<path>`                                | Remove a file from the document list                                                                |
| **remove** `<source>` **documents**                | Bulk-remove all documents from a specific source (e.g. `remove notion documents`)                   |
| **add** `<path>`                                   | Validate path, `stat` for `byteSize`, append metadata only (do not read file contents until upload) |
| **skip tasks**                                     | Remove the Tasks section — no tasks will be imported                                                |
| **change title** / **title:** `<new title>`        | Override project title                                                                              |
| **change description** / **description:** `<text>` | Override project description                                                                        |
| **look at** `<folder>` **instead**                 | Alias for `change folder` — re-scan a new folder                                                    |
| **change folder** `<path>`                         | Re-scan a new folder — **resets** title, description, document list, and tasks                      |

**Budget feedback on `add`:** Before appending, `stat` the file and check whether total selected `byteSize` would exceed
**500 KB**. If so, warn immediately:

> Adding `big-spec.md` (120 KB) would bring the total to 580 KB, over the ~500 KB we keep for a focused initial project.
> Consider removing a large file first, or approve and I'll include it anyway.

If the user already has **15** selected files, warn that they should `remove` one before adding unless they explicitly
want to exceed the doc cap.

**Precedence:** `change folder` wipes prior edits and re-derives everything from the new scan. Other edits stack on the
latest scan until `change folder` runs.

Re-render the manifest after each edit. Loop until the user approves or cancels.

### 6. Upload

On approve:

**Extract `.doc`/`.docx`** — for each document ending in `.doc`/`.docx`, run
`pandoc -t plain --wrap=none "<path>" -o "<path>.txt"` via Bash. If pandoc is missing: skip those files (warn) if other
docs remain, or abort if only `.doc`/`.docx` files are present. Use the converted `.txt` path in the upload.

**Create the project** — call `create_project` with `{ title, description }`. Store `projectId` and `url`.

**Upload local documents** — for each manifest document that has a `filePath`, call `upload_document` once with the
project ID. The tool reads the file from disk and streams bytes to storage (do NOT read file contents into the agent or
pass them in the tool call). Use absolute paths only; the server rejects common credential locations (`.ssh`, `.aws`,
`.kestral`, `.env`, etc.). If `upload_document` isn't available, reconnect **Kestral** — see Prerequisites.

```json
{
  "filePath": "/absolute/path/to/scanned/folder/README.md",
  "projectId": "<projectId>"
}
```

Each call returns `{ documentId, title, url }`. Track per-file success/failure across the calls.

**Link external (MCP-sourced) documents** — for each manifest document that has a `sourceUrl` (no `filePath`), call
`link_external_document` once. Do **not** call `create_document` for these — that copies the content inline, loses
source provenance, and breaks autosync.

```json
{
  "url": "<sourceUrl from manifest>",
  "title": "<doc title>",
  "projectId": "<projectId>",
  "content": "<contentText from manifest>"
}
```

`url` is the canonical source URL (required). `title` and `content` are fallbacks the server uses only when no matching
Kestral integration is connected yet — once it is, the server-side fetch is authoritative. Each call returns
`{ documentId, title, url, resolutionStatus, linkedToProject }`. Note `resolutionStatus`. `linkedToProject` is `true`
only when this call newly attached the doc; a `false` with no error means the doc was already linked (re-run/dedup), not
a failure. Track per-doc success/failure across the calls.

- `"ready"` — the link resolved and Kestral synced the authoritative content now. Done.
- `"pending"` — **partial success**: Kestral stored your `content` snapshot and linked it, but the matching integration
  isn't connected, so it can't keep the doc in sync. Collect the distinct sources of all pending docs and nudge the user
  once at the end (see "Present results") to connect them in Kestral so the docs autosync to their authoritative version.

**Document upload outcomes:**

- If some documents failed, report which ones and why.
- If all failed: "Upload failed — no documents were saved. The project is at `<url>` — you can add files manually, or
  delete it and run `/kestral:kestral-setup` again."

On 401 from any tool, tell the user to reconnect the MCP server to re-authenticate, then retry.

**Trigger brain generation** — call `trigger_brain_build` with `{ projectId }`. Capture the response (do
not fail the overall flow on error). Three response cases:

| Response                                           | User-facing message                                                                                                                       |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `enqueued: true`                                   | "Brain is generating — usually 1–2 minutes."                                                                                              |
| `enqueued: false, reason: 'feature-flag-disabled'` | "Project created. Project Brain isn't enabled for this workspace — ask your admin to turn it on, then open `<url>` and click 'Generate'." |
| `enqueued: false, reason: 'system-error'`          | "Project created. Brain generation couldn't start (ref `<supportRef>`). Open `<url>` and click 'Generate' to retry."                      |

**Import tasks** — if the manifest includes tasks (non-empty `tasks` array from `scan-tasks`), call
`create_tasks` with `{ projectId, tasks }`. Capture `created` and `failed` from the response. Do not
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
>
> \<pending-links nudge — only if any linked doc returned `resolutionStatus: "pending"`\>

**Pending-links nudge:** If one or more linked docs came back `pending`, add a single line naming the distinct sources
and pointing the user to connect them — the snapshot is in place, connecting just upgrades it to a live, autosynced copy:

> I linked your Notion and Google Drive docs from a saved snapshot. Connect those integrations in Kestral
> (**Workspace Settings → Integrations**) and they'll autosync to the latest version.

Task summary format:

- All succeeded: "Imported X tasks from \<source\>."
- Some failed: "Imported X tasks from \<source\>; Y could not be imported."
- All failed: "Project + docs uploaded. Task import failed — you can retry from the project page."

### 7. Encourage next steps

Skip if no project was created. Close with a short, inviting nudge — don't lecture.

**Point them at the brain** (only when `enqueued: true`):

> Once the brain finishes (~1–2 min), open **\<url\>** to see your project's status, blockers, and suggested next steps —
> it's the fastest way to spot what's in your way.

**Offer follow-up actions** — present as options, don't auto-run any:

> Want me to keep going? I can:
> • **Add more context** — point me at more local files, a Notion or Google Drive doc, or recent work and I'll add it to
>   this project and refresh the brain.
> • **Help clear blockers** — once the brain flags blockers, tell me and I'll pull those tasks up so we can work them.
> • **Loop in your team** — teammates need to be in your Kestral workspace to see this. Invite them in Kestral under
>   **Workspace Settings → Members**, then they'll have access — especially worth it if a blocker depends on someone else.

When the user picks one, map it to the right tools:

| User picks        | Do this                                                                                                                                                                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Add more context  | Treat the new files/sources like steps 3 / 3a (scan locally or pull from a connector). For each **local** file, call `upload_document` with `{ filePath, projectId }`. For each **external (MCP-sourced)** doc (has `sourceUrl`, no disk path), call `link_external_document` with `{ url: sourceUrl, title, projectId, content }` — never `create_document`, which copies content inline and breaks autosync. Then re-run `trigger_brain_build` to refresh the brain. |
| Help clear blockers | Hand off to `tasks/SKILL.md`. Use `search_tasks({ projectId })` to list this project's open tasks and let the user pick which to work on next.                                                                                          |
| Loop in team      | Sharing the URL alone won't grant access — teammates must be members of the workspace. Tell the user to invite them in Kestral under **Workspace Settings → Members**                     |

## Cancel behavior

On cancel, confirm:

> Cancelled. No changes were made in Kestral.

Do not call any write MCP tools.

## Error message reference

See `docs/manifest-copy-spec.md` for the full error message table. All error messages in this skill MUST match the exact
wording specified there.
