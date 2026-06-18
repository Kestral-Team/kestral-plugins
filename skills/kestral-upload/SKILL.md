---
name: kestral-upload
description: Use when a setup manifest is approved and the user or kestral-setup asks to apply it, attach documents, import tasks, or invokes /kestral:upload or $kestral-upload.
---

# Upload

Create one or more Kestral projects from approved setup manifests, upload or link selected documents, import tasks when
provided by the caller, and trigger Project Brain generation after project context is attached.

## Prerequisites

A **Kestral** MCP server must be in this session (`/mcp`). Call `whoami` first — if it fails, ask the user to
reconnect or authenticate the **Kestral** MCP server in their app's MCP settings. The agent cannot handle OAuth
directly — authenticate through your app's UI (Cowork: Customize → Connectors; Codex: Settings → MCP Servers →
Authenticate; Claude Code: `/mcp` → reconnect).
Do not call other tools until authenticated.

Local file uploads use Kestral-owned upload URLs (`upload_request_urls` → PUT → response includes the document record).
There is no separate finalize step. This requires network egress from the agent sandbox to `app.kestral.ai`. If uploads
fail with a network error, guide the user:

- **Claude Cowork:** **Settings → Capabilities** → enable **"Allow network egress"** → add `app.kestral.ai` as an
  allowed domain.
- **Codex:** **Settings → Configuration** → enable **"Allow network access"**.
- **Cursor:** Grant network access when prompted, or add `app.kestral.ai` to allowed domains.

Missing upload tools or blocked egress do not block project creation, task import, or external doc linking. Text files
can be uploaded as inline content via `create_document`. Binary files (PDFs, images) require egress or manual upload
through the Kestral web app.

## Inputs

From the scan step or user edits at the manifest checkpoint:

- `projects` — array of approved manifests:
  - `title` — project title
  - `description` — project description (optional)
  - `documents` — array of selected documents. Local docs include `{ filename, relativePath, byteSize, filePath }`;
    external docs include canonical `url`, `title`, `source`, and optional fallback `content`.
  - `tasks` — array of `{ title, description?, source, priority?, dueDate? }` from `scan-tasks` or user edits
  - `bulkImportRequested` — optional flags by source or item type when the user approved importing more/all matching
    context into this project

## Human-readable references

Keep Kestral IDs internal unless the user asks for them. In user-facing output:

- Tasks: show `slug - title` when a slug is available, linked with `url` when the host can render links.
- Projects, documents, feedback, customers, tags, statuses, and other Kestral entities: show the readable name/title/label
  first, linked with `url` when the host can render links.
- People and actors: show display names; if unresolved, write `Unknown member (id: <rawId>)`.
- Unknown non-member entities: write `Unknown <entity type> (id: <rawId>)`.
- Approval tables and write-back plans must put the human-readable label first. Raw URLs, machine IDs, source IDs, and
  bare slugs belong only in secondary metadata when useful.
- Use existing display fields first; do extra lookups only for entities that matter to the answer.

## Workflow

Apply each approved project. Preserve successful project URLs even when later uploads, task creation, or Project Brain
generation fail for one project.

### 1. Create project

Call `create_project` with `{ title, description }`. Store `projectId` and `url` from the response.

### 2. Upload documents

Try the best available upload tool. On network/egress failure, help the user fix it and retry.

**Step 1: Try upload**

- `upload_document` available → `upload_document({ filePaths, projectId, explanation })`. Streams from disk; absolute
  paths only; credential locations rejected. Returns `{ documentId, title, url }` or `{ documents, failed }`.
- `upload_request_urls` available (max 50 files/request) → derive `contentType` from each file's extension
  (e.g. `.md` → `text/markdown`, `.pdf` → `application/pdf`) and use `byteSize` from scan-folder as `sizeBytes`:
  1. `upload_request_urls({ projectId, files: [{ filename, relativePath, contentType, sizeBytes }], explanation })`
  2. `curl -X PUT -H "Content-Type: <type>" -T "<path>" "<uploadUrl>"` per file — the PUT response returns the
     completed document record (`{ documents: [{ id, title, sourceUrl }] }`), so there is no separate finalize step.
- Neither available → use the fallback below.

**Step 2: On upload failure (network/egress error)**

Give platform-specific egress fix instructions:

- **Claude Cowork:** **Settings → Capabilities** → enable **"Allow network egress"** → add `app.kestral.ai` as an
  allowed domain.
- **Codex:** **Settings → Configuration** → enable **"Allow network access"**.
- **Claude Code:** No restrictions — check connectivity.

After giving instructions, explicitly prompt the user to tell you when they're ready:

> Let me know when you've updated the setting and I'll retry the upload.

Wait for the user's response, then retry the upload. If upload still fails after retry, use the fallback below.

**Fallback — create documents from file content**

If no upload tool is available, or upload fails and cannot be recovered:

Read text/markdown via Read tool → `create_document({ title, content, projectId, explanation })`. Skip binary files
with a message pointing to manual upload from the Kestral project page.

On 401, tell user to reconnect and retry. Report failures per-file.

**External documents:** `link_external_document({ url, title, projectId, content? })`. Never use `create_document` for
external docs — it loses provenance and autosync. Track `resolutionStatus` for pending-link reporting.

**Inline content** (pasted text, summaries — not a file or URL): `create_document({ title, content, projectId,
explanation })`. Confirm the response shows the document is linked to the project.

### 3. Import tasks

If a project's `tasks` input is non-empty, call `create_tasks` with `{ projectId, tasks }`. Capture `created` and
`failed`. Do not fail the overall flow if some tasks fail. Skip entirely if `tasks` is empty or not provided. For
approved bulk imports, batch by project and source and continue reporting partial success.

### 4. Trigger brain generation

Call `trigger_brain_build` with `{ projectId }` after selected documents and tasks have been attached. Capture the
response — do not fail the overall flow on error. Three response cases:

| Response                                           | User-facing message                                                                                                          |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `enqueued: true`                                   | "Brain is generating — usually 1–2 minutes."                                                                                 |
| `enqueued: false, reason: 'feature-flag-disabled'` | "Project Brain isn't enabled for this workspace — ask your admin to turn it on, or generate it from the project page later." |
| `enqueued: false, reason: 'system-error'`          | "Brain couldn't start (`<supportRef>`) — open the project and click 'Generate'."                                             |

### 5. Present results

Use readable project and document titles with URLs. For imported tasks, summarize by count/source; if individual tasks
are listed, use task titles or `slug - title` when slugs are available.

Print each project by readable title linked to its URL, and summarize all outcomes:

> Your project is ready: [\<project title\>](\<url\>)
>
> **Documents:** N/M uploaded or linked successfully. \<list failures or pending links if any\>
>
> **Brain:** \<message from the Brain response table above\>
>
> **Tasks:** \<task summary — only if tasks were attempted\>

Task summary format:

- All succeeded: "Imported X tasks from \<source\>."
- Some failed: "Imported X tasks from \<source\>; Y could not be imported."
- All failed: "Could not import tasks — you can add them manually in Kestral."

If all documents failed: "Upload failed — no documents were saved. The project was created: [\<project title\>](\<url\>).
You can add files manually, or delete it and try again."

When multiple projects were approved, repeat the same compact summary per project and include every successful project
URL. One project's failure does not hide successful results from other projects.

## Error handling

- If `create_project` fails for one project, surface that project's error and continue with other approved projects when
  safe.
- Document upload/link failures, brain trigger failures, and task import failures are non-fatal after a project exists —
  always present the project URL.
