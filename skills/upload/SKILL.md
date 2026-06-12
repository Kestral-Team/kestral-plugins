---
name: kestral-upload
description: Use when a setup manifest is approved and the user or kestral-setup asks to apply it, attach documents, import tasks, or invokes /kestral:upload or $kestral-upload.
---

# Upload

Create one or more Kestral projects from approved setup manifests, upload or link selected documents, import tasks when
provided by the caller, and trigger Project Brain generation after project context is attached.

## Prerequisites

A **Kestral** MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth (browser opens on first use).

Local file uploads use `upload_document` on **Kestral** — including Claude Cowork. If `upload_document` is not in the
tool list, reconnect **Kestral** in the client and retry — do not send the user to another app for uploads.

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

For selected local documents, pass the project ID so each file is attached. Use
`upload_document({ filePaths, projectId, explanation })` to upload one or more files in a single call.

Single-file call shape:

```json
{
  "filePaths": ["/absolute/path/to/scanned/folder/README.md"],
  "projectId": "<projectId>",
  "explanation": "Uploading the selected README into the approved Kestral setup project."
}
```

`upload_document` streams bytes from disk straight to storage via a presigned URL. Do NOT pass file contents; bytes never
pass through the agent's model context. Exact file support and hard upload limits are enforced by MCP/server behavior,
not this skill. The skill may pass likely document, image, audio, video, and text candidates, then report any unsupported
or oversized files from the upload result without blocking the rest. Use absolute paths only; the server rejects common
credential locations (`.ssh`, `.aws`, `.kestral`, `.env`, etc.).

Single-file calls return `{ documentId, title, url }`; batch calls may return `{ documents, failed }`. Track per-file
success/failure in either shape. On 401, tell the user to reconnect the MCP server, then retry.

For selected external documents, call `link_external_document` with `{ url, title, projectId, content? }`. Never use
`create_document` for external docs; it loses source identity and autosync behavior. Track `resolutionStatus` so pending
links can be reported as partial success.

For **agent-authored inline content** (Slack thread pasted in chat, meeting summary, notes the agent is writing — not a
file on disk and not an external URL), call `create_document` with `{ title, content, projectId, explanation }`. The
document is created and attached to the project in one call. Confirm from the response that the document is linked to
the project.

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
