---
description: Create a Kestral project, upload documents, trigger brain, and import tasks
disable-model-invocation: true
---

# Upload

Create a Kestral project with documents from the scan manifest, trigger brain generation, and import
tasks (if provided by the caller).

## Prerequisites

- `~/.kestral/credentials` exists with an `api_key` line (run `/kestral:init` first if not).
- MCP server connected (`/mcp` shows `kestral` connected).

## Inputs

From the scan step or user edits at the manifest checkpoint:

- `title` — project title
- `description` — project description (optional)
- `documents` — array of `{ filename, relativePath, byteSize, filePath }`
- `tasks` — (optional) array of `{ title, description?, source, priority?, dueDate? }` from `scan-tasks`

## Workflow

### 0. Content budget check

Before creating the project or uploading, sum `byteSize` for all documents in the manifest (sizes captured during scan).

`byteSize` is on-disk size. For `.doc`/`.docx`, extracted text size may differ — the budget is approximate when those
files are included.

- If total **≤ 500 KB** — continue.
- If total **> 500 KB** — warn before proceeding:

  > Total content is ~580 KB, which may exceed Claude's context window during upload (each file is read and sent in a
  > separate tool call). Consider `remove`ing large files at the manifest checkpoint, or approve and I'll upload until
  > the session risks failing.

This is a safety rail — scan should already cap at 15 docs / 500 KB, but the user may have `add`ed large files at the
checkpoint.

### 1. Extract `.doc`/`.docx` to plain text

For each document whose filename ends in `.doc` or `.docx`:

1. Check `pandoc` is available: `command -v pandoc`
2. If missing:
   - If **other** non-doc documents remain, **skip** the `.doc`/`.docx` files and warn.
   - If **only** `.doc`/`.docx` files remain, **abort** with install instructions.
3. If available: `pandoc -t plain --wrap=none "<path>" -o "<path>.txt"` and update `filePath` to the `.txt` output.

### 2. Create empty project

Call `kestral_create_project`:

```json
{
  "title": "<title>",
  "description": "<description>"
}
```

Store `projectId` and `url` from the response.

### 3. Upload all documents

Call `kestral_upload_documents` with file paths:

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

Every `filePath` must lie under `scanRoot`.

The MCP server reads files from disk — do NOT pass file contents. Use absolute paths only.

- On 401: delete `~/.kestral/credentials`, re-run auth, then retry.

### 4. Trigger brain generation

Call `kestral_trigger_project_brain_build` with `{ projectId }`. Capture the response — do not fail the
overall flow on error. Three response cases:

| Response | User-facing message |
| --- | --- |
| `enqueued: true` | "Brain is generating — usually 1–2 minutes." |
| `enqueued: false, reason: 'feature-flag-disabled'` | "Project Brain isn't enabled for this workspace — ask your admin to turn it on, or generate it from the project page later." |
| `enqueued: false, reason: 'system-error'` | "Brain couldn't start (`<supportRef>`) — open the project and click 'Generate'." |

### 5. Import tasks

If `tasks` input is non-empty, call `kestral_create_project_tasks` with `{ projectId, tasks }`. Capture
`created` and `failed` from the response. Do not fail the overall flow if some tasks fail.

Skip this step entirely if `tasks` is empty or not provided.

### 6. Present results

Print the project URL and summarize all outcomes:

> Your project is ready: **\<url\>**
>
> **Documents:** N/M uploaded successfully. \<list failures if any\>
>
> **Brain:** \<message from step 4 table\>
>
> **Tasks:** \<task summary — only if tasks were attempted\>

Task summary format:

- All succeeded: "Imported X tasks from \<source\>."
- Some failed: "Imported X tasks from \<source\>; Y could not be imported."
- All failed: "Could not import tasks — you can add them manually in Kestral."

If all documents failed: suggest **deleting the incomplete project** in the Kestral UI and re-running, or
keeping it and adding missing files manually.

## Error handling

- If `kestral_create_project` fails, surface the error — no cleanup needed.
- Brain trigger and task import failures are non-fatal — always present the project URL.
- Never print the raw API key.
