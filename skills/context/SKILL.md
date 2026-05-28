---
description: Pull Kestral docs, projects, and tasks into the chat as context for the agent
disable-model-invocation: true
---

# Context

Search your Kestral workspace and pull relevant documents, projects, and tasks into the conversation.
This gives the agent real workspace knowledge so it can answer questions like "what's the latest on the
auth migration?" without you having to paste anything.

## Prerequisites

- The Kestral MCP server must show as **connected** (`/mcp` → `kestral` connected).
- The `kestral` MCP server must be connected. Authentication is handled automatically via OAuth — the MCP client opens a browser for login on first use.

## Workflow

### 1. Authenticate

Authentication is handled automatically via OAuth. If a tool call fails with 401, tell the user to reconnect the MCP server.

### 2. Get the query

The user's prompt after `/kestral:context` is the search topic. Examples:

- `/kestral:context auth migration`
- `/kestral:context what do customers say about onboarding?`
- `/kestral:context project roadmap for Q3`

If the prompt is empty, ask: "What topic should I search for in your Kestral workspace?"

### 3. Search across entity types

Run three searches in parallel using the user's query:

1. `search_documents({ query: "<topic>", limit: 5 })`
2. `search_projects({ query: "<topic>", limit: 5 })`
3. `search_tasks({ query: "<topic>", limit: 5 })`

### 4. Present the context manifest

Show what was found so the user can choose what to pull in:

```
Found in Kestral for "auth migration":

  Documents (3):
    1. Auth Migration Plan                     (spec, 12.4 KB)
    2. OAuth Provider Comparison               (notes, 6.1 KB)
    3. Security Review — Auth Q2               (report, 8.3 KB)

  Projects (1):
    4. Auth Overhaul                           (active, 8 tasks)

  Tasks (4):
    5. Migrate OAuth tokens to new format      (in_progress, high)
    6. Update redirect handler                 (todo, medium)
    7. Write migration rollback script         (todo, medium)
    8. QA auth flow on staging                 (todo, low)

Which items should I pull into context? (numbers, "all", "docs only", or "skip")
```

**Rules:**

- Number every item sequentially across categories for easy selection.
- Show document type and approximate size (from search result metadata) when available.
- Show project lifecycle status and task count.
- Show task status and priority.
- If a category has zero results, omit it from the display.
- If all three searches return zero results: "I didn't find anything in Kestral matching that topic.
  Try different keywords or check that the relevant project/docs exist."

### 5. Pull selected content

Based on the user's selection:

#### Documents

For each selected document, call `get_document_content({ workContextId: "<id>" })`.

- Default read: up to 50,000 characters (the tool's default `length`).
- The response includes `isTruncated` (boolean) and `nextOffset` (number or null). If `isTruncated`
  is `true`, call again with `offset` set to `nextOffset`. Repeat until `isTruncated` is `false` or
  total loaded content exceeds **200 KB** — then stop and note the truncation.
- Present each document's content in the chat with a clear header:

```
─── Auth Migration Plan (spec) ───

<document content here>

──────────────────────────────────
```

#### Projects

For each selected project, call `get_project({ projectId: "<id>" })`.

Present project details:

```
─── Project: Auth Overhaul ───

  Status:       active
  Description:  Migrate from legacy OAuth to OIDC provider…
  Due:          2026-07-01
  Tasks:        8 total (3 in progress, 5 todo)

───────────────────────────────
```

#### Tasks

For each selected task, call `get_task({ taskId: "<id>", includeComments: true })`.

Present task details in the same format as the `/kestral:tasks` drill-down view (see
`tasks/SKILL.md` step 4).

### 6. Summarize

After pulling content, confirm what was loaded:

> Loaded 3 documents (~27 KB), 1 project, and 4 tasks into context. You can now ask me questions
> about them.

The agent now has this content in its conversation context and can reason about it in subsequent
messages.

## Limits

- **Per-document cap:** 200 KB of text content. If a document exceeds this, load the first 200 KB and
  note: "Document truncated at 200 KB. Use `get_document_content` with `offset` to read further."
- **Total context budget:** If the user selects "all" and total content would exceed **500 KB**, warn
  before loading:

  > That's ~620 KB of content, which may reduce available context for our conversation. Load anyway,
  > or pick specific items?

  Proceed only if the user confirms.

## Error handling

| Failure | Message |
| --- | --- |
| 401 / unauthorized | "Authentication expired. Please reconnect the MCP server to re-authenticate." |
| Document not found | "Document `<id>` not found — it may have been deleted. Skipping." |
| Search returned error | "Search failed: `<error>`. Try again or check that the MCP server is connected (`/mcp`)." |
