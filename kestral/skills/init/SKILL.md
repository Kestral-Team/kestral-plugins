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
- If MCP is **disconnected**: check that the MCP server URL in `.mcp.json` is reachable (e.g.
  `curl <url from .mcp.json>` should respond). If the server is down or unreachable, the plugin cannot function. After
  fixing the connection, **fully quit and restart** Claude Code so it reconnects.

## Workflow

### 1. Authenticate

Authentication uses OAuth and is handled automatically by the MCP client. On the first tool call, the client will open a
browser window for the user to log in and authorize access. Tokens are managed and refreshed automatically.

If a tool call fails with a 401, tell the user to reconnect the MCP server to re-authenticate.

### 2. Ask for source

Ask the user:

> Which folder should I scan? (Or list specific file paths.)

Accept either a directory path or a comma/newline-separated list of files.

### 3. Scan the folder

**Discover files.** If a folder path was given, use `Glob` with pattern `**/*.{md,txt,doc,docx}` rooted at that folder.
If explicit files were given, validate each exists.

- If the folder doesn't exist: "I couldn't find `<path>`. Try another folder or file set."
- If no eligible files found: note the absence but **do not stop** — continue to step 3a (MCP documents) first.
  MCP-sourced docs alone are sufficient to create a project. Only if no documents exist after step 3a, show: "I didn't
  find any documents to upload — no eligible local files in `<path>` and no MCP document sources available. Point me
  somewhere else?"

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
- `filePath` — absolute path on disk (used by `kestral_upload_documents`)

Do **not** read full contents for every discovered file during scan — only the ~5 used for title/description, plus any
file the user `add`s at the checkpoint.

### 3a. Scan MCP documents (optional)

After the local folder scan, check for MCP-connected document sources. This step mirrors how scan-tasks works — the
orchestrator (`init`) owns MCP tool enumeration because it has visibility into the conversation's loaded tools.

1. **Detect doc MCPs.** Inspect available MCP tools. Identify doc-shaped MCPs: tool names or descriptions mentioning
   `document`, `note`, `page`, `file`, or known sources (Granola, Notion, Google Drive, Confluence).
2. **Prompt the user.** For each detected source, ask: "Want me to include relevant documents from `<source>` too?"
3. **List and filter.** If yes, call the listing tool with a sensible default filter (e.g. recently modified). Use
   judgment to limit to relevant docs — do not dump hundreds of items.
4. **Record docs.** For each included doc, record `{ filename, relativePath, contentText, contentLength }`. Derive
   `filename` from the doc title (e.g. `"Q4 Planning Notes"` → `"Q4 Planning Notes.md"`). Use `<source>/<filename>` as
   `relativePath` (e.g. `"granola/Q4 Planning Notes.md"`). Set `contentLength` to the character count of `contentText`
   (approximate byte size). These fields match the `kestral_create_project_with_documents` document schema.
5. **Add to manifest.** MCP-sourced docs appear in the manifest with source label `[<source>]` and approximate size
   derived from `contentLength` (e.g. `(~12.3 KB)`).

If no doc MCPs detected: skip silently — do not tell the user about the absence.

**Error handling:** If listing fails for a source: "I couldn't list documents from `<source>` — skipping." If local
files or other MCP sources remain, note them ("Other sources still included."). Continue with remaining sources.

### 3b. Scan tasks

Follow the `scan-tasks/SKILL.md` workflow. This detects connected task MCPs (Linear, Jira, GitHub Issues, etc.), lists
open + recently completed tasks, and translates them to the Kestral import schema.

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

**Extract `.doc`/`.docx`** — for each document ending in `.doc`/`.docx`, run
`pandoc -t plain --wrap=none "<path>" -o "<path>.txt"` via Bash. If pandoc is missing: skip those files (warn) if other
docs remain, or abort if only `.doc`/`.docx` files are present. Use the converted `.txt` path in the upload.

**Choose upload path** based on whether MCP-sourced documents are in the manifest.

#### Path A: Local documents only (no MCP docs)

**Create the project** — call `kestral_create_project` with `{ title, description }`. Store `projectId` and `url`.

**Upload documents** — call `kestral_upload_documents` with the project ID, the scanned folder root, and file paths:

```json
{
  "projectId": "<projectId>",
  "scanRoot": "/absolute/path/to/scanned/folder",
  "documents": [
    { "filePath": "/absolute/path/to/scanned/folder/README.md", "relativePath": "README.md" },
    { "filePath": "/absolute/path/to/scanned/folder/docs/arch.md", "relativePath": "docs/arch.md" }
  ]
}
```

Every `filePath` must lie under `scanRoot`. The MCP server rejects paths outside that root and common credential
locations (`.ssh`, `.aws`, `.kestral`, `.env`, etc.).

The MCP server reads file contents from disk — do NOT pass file contents in the tool call. Use absolute paths only.

The response includes per-file success/failure:

- If some files failed, report which ones and why.
- If all failed: "Upload failed — no documents were saved. The project is at `<url>` — you can add files manually, or
  delete it and run `/kestral:init` again."

#### Path B: Local + MCP documents (mixed sources)

When MCP-sourced docs are present, use a single atomic call that creates the project and uploads all documents together.
This avoids the need for a separate "add document to existing project" tool (which doesn't exist as an MCP tool).

**Read local file contents** — for each local document in the manifest, read its content as plain text. For `.doc`/
`.docx` files, extract via pandoc first (same as Path A). This is required because
`kestral_create_project_with_documents` accepts content text, not file paths.

**Create project with all documents** — call `kestral_create_project_with_documents` with the project title,
description, and all documents (local + MCP-sourced) combined:

```json
{
  "title": "<project title>",
  "description": "<project description>",
  "documents": [
    { "filename": "README.md", "relativePath": "README.md", "contentText": "<file contents>" },
    { "filename": "architecture.md", "relativePath": "docs/architecture.md", "contentText": "<file contents>" },
    { "filename": "Q4 Planning Notes.md", "relativePath": "granola/Q4 Planning Notes.md", "contentText": "<doc text from MCP>", "source": "granola" }
  ]
}
```

**Source attribution:** For MCP-sourced documents, include the `source` field (e.g. `"granola"`, `"notion"`, `"gdrive"`)
so the server stores the correct origin in `metadata.claudeCodePlugin.source`. Omit `source` for local files — the
server defaults to `"local-folder"`.

The tool accepts at most 50 documents per call. The 15-file selection cap means this limit is unlikely to be hit, but if
MCP docs push the total past 50, split the upload as follows:

1. **First batch** (`kestral_create_project_with_documents`, up to 50): include **all MCP-sourced documents first**
   (they require `contentText` and have no disk path), then fill remaining slots with local documents.
2. **Overflow local docs** (`kestral_upload_documents`): any local documents that didn't fit in the first batch. These
   have on-disk `filePath`s so the file-path-based tool works.
3. **Overflow MCP docs** (unlikely — requires 50+ MCP-sourced docs alone): write each overflow MCP document's
   `contentText` to a temporary file (`mktemp`) and upload via `kestral_upload_documents` using that temp path. Clean up
   temp files after upload completes.

Store `projectId` and `url` from the response.

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

## Cancel behavior

On cancel, confirm:

> Cancelled. No changes were made in Kestral.

Do not call any write MCP tools.

## Error message reference

See `docs/manifest-copy-spec.md` for the full error message table. All error messages in this skill MUST match the exact
wording specified there.
