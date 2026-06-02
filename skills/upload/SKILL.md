---
name: kestral-upload
description: Create a Kestral project, upload documents, trigger brain, and import tasks. Use when the user or kestral-setup asks to upload an approved manifest.
---

# Upload

Create a Kestral project with documents from the scan manifest, trigger brain generation, and import tasks (if provided
by the caller).

## Prerequisites

The `kestral` MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth (browser opens on first use).

## Inputs

From the scan step or user edits at the manifest checkpoint:

- `title` — project title
- `description` — project description (optional)
- `documents` — array of `{ filename, relativePath, byteSize, filePath }`. **Local files only** — every doc must have a
  `filePath`. Linked external docs (Notion/Drive/Slack, no `filePath`) are handled by `kestral-setup`'s own upload step
  via `link_external_document`, not here.
- `tasks` — (optional) array of `{ title, description?, source, priority?, dueDate? }` from `scan-tasks`

## Workflow

### 1. Create project

Call `kestral_create_project` with `{ title, description }`. Store `projectId` and `url` from the response.

### 2. Upload documents

Call `upload_document` once per document, passing the project ID so each file is attached:

```json
{
  "filePath": "/absolute/path/to/scanned/folder/README.md",
  "projectId": "<projectId>"
}
```

The local MCP bridge streams bytes from disk straight to storage via a presigned URL — do NOT pass file contents (bytes
never pass through the agent), so upload size never affects Claude's context, no matter how many files or how large. The
server enforces an allowed file-type list and a per-file size limit (tens of MB for text/PDF/DOCX, larger for
audio/video); an oversized or unsupported file fails on its own (reported in step 5) without blocking the rest. Use
absolute paths only; the server rejects common credential locations (`.ssh`, `.aws`, `.kestral`, `.env`, etc.).

Each call returns `{ documentId, title, url }`. Track per-file success/failure. On 401, tell the user to reconnect the
MCP server, then retry.

### 3. Trigger brain generation

Call `kestral_trigger_project_brain_build` with `{ projectId }`. Capture the response — do not fail the overall flow on
error. Three response cases:

| Response                                           | User-facing message                                                                                                          |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `enqueued: true`                                   | "Brain is generating — usually 1–2 minutes."                                                                                 |
| `enqueued: false, reason: 'feature-flag-disabled'` | "Project Brain isn't enabled for this workspace — ask your admin to turn it on, or generate it from the project page later." |
| `enqueued: false, reason: 'system-error'`          | "Brain couldn't start (`<supportRef>`) — open the project and click 'Generate'."                                             |

### 4. Import tasks

If `tasks` input is non-empty, call `kestral_create_project_tasks` with `{ projectId, tasks }`. Capture `created` and
`failed`. Do not fail the overall flow if some tasks fail. Skip entirely if `tasks` is empty or not provided.

### 5. Present results

Print the project URL and summarize all outcomes:

> Your project is ready: **\<url\>**
>
> **Documents:** N/M uploaded successfully. \<list failures if any\>
>
> **Brain:** \<message from step 3 table\>
>
> **Tasks:** \<task summary — only if tasks were attempted\>

Task summary format:

- All succeeded: "Imported X tasks from \<source\>."
- Some failed: "Imported X tasks from \<source\>; Y could not be imported."
- All failed: "Could not import tasks — you can add them manually in Kestral."

If all documents failed: "Upload failed — no documents were saved. The project is at `<url>` — you can add files
manually, or delete it and try again."

## Error handling

- If `kestral_create_project` fails, surface the error — no cleanup needed.
- Brain trigger and task import failures are non-fatal — always present the project URL.
