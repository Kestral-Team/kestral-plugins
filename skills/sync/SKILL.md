---
name: kestral-sync
description: Use when the user asks to save notes, summaries, or Slack context to a Kestral project, keep project context up to date from chat, or invokes /kestral:sync or $kestral-sync.
---

# Sync context to Kestral

Save new information from the conversation into the right place in Kestral — as a project document, file upload, or
external link — without stuffing long text into a project description.

## Prerequisites

The **Kestral** MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth (browser opens on first use).

## Which tool to use

| What the user wants to store | Tool | Notes |
| ---------------------------- | ---- | ----- |
| New text from chat (Slack thread, summary, notes, specs) | `create_document` with `projectId` | **Preferred** — creates and attaches in one step |
| A file on their computer | `upload_document` | Local Kestral bridge only; streams from disk |
| A link in Notion, Drive, Slack, Confluence | `link_external_document` | Keeps live sync with the source |
| Change tasks, tags, status, or project title | `project_management`, `update_task`, or `update_project` | **Not** for uploading new document body text |
| Short project blurb only | `update_project` description | One or two sentences — not a full context dump |

## Workflow

### 1. Resolve the project

If the user names a project, use `entity_lookup` or `query_entities` to find its ID. Keep IDs internal unless the user
asks for them.

### 2. Store the content

- **Inline text:** Call `create_document` with a clear `title`, the full `content`, and `projectId`. Confirm the
  response shows the document is linked to the project.
- **Local file:** Call `upload_document` with `filePaths` and `projectId`.
- **External link:** Call `link_external_document` with `url`, `title`, and `projectId`.

Do **not** call `project_management` to upload pasted content. Do **not** append long text to `update_project`
description.

### 3. Confirm for the user

Present the document title linked with `url` from the tool response. Say clearly when the document was attached to the
named project.

## Error handling

- On 401, ask the user to reconnect Kestral in their MCP settings, then retry.
- If attachment looks wrong after `create_document`, look up the document again and check which projects it belongs to
  before trying to attach it separately.
