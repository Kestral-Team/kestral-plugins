---
name: kestral-context
description: Use when the user explicitly asks to search Kestral workspace context, pull Kestral documents, projects, or tasks into chat, or invokes /kestral:context or $kestral-context.
---

# Context

Search your Kestral workspace and pull relevant documents, projects, and tasks into the conversation. This gives the
agent real workspace knowledge so it can answer questions like "what's the latest on the auth migration?" without you
having to paste anything.

## Prerequisites

The `Kestral` MCP server must be in this session (`/mcp`). Authentication is handled by the MCP connection (OAuth) —
proceed directly with operations. If any call returns auth failure (401, unauthorized, or `Not authenticated`), ask the
user to reconnect or authenticate through their app's UI (Cowork: Customize → Connectors; Codex: authenticate then
start a new thread using `/new` — CLI: `codex mcp login Kestral`; app: Plugins → Kestral → MCP servers gear; Claude Code: `/mcp` →
reconnect).

## Human-readable references

Keep Kestral IDs internal unless the user asks for them. In user-facing output:

- Tasks: show `slug - title` when a slug is available, linked with `url` when the host can render links.
- Projects, documents, feedback, customers, tags, statuses, and other Kestral entities: show the readable
  name/title/label first, linked with `url` when the host can render links.
- People and actors: show display names; if unresolved, write `Unknown member (id: <rawId>)`.
- Unknown non-member entities: write `Unknown <entity type> (id: <rawId>)`.
- Approval tables and write-back plans must put the human-readable label first. Raw URLs, machine IDs, source IDs, and
  bare slugs belong only in secondary metadata when useful.
- Use existing display fields first; do extra lookups only for entities that matter to the answer.

## Workflow

### 1. Get the query

The user's prompt after `/kestral:context` is the search topic. Examples:

- `/kestral:context auth migration`
- `/kestral:context what do customers say about onboarding?`
- `/kestral:context project roadmap for Q3`

If the prompt is empty, ask: "What topic should I search for in your Kestral workspace?"

### 2. Search across entity types

Run searches in parallel using the user's query:

1. `execute_operation("find_documents", { query: "<topic>" })`
2. `execute_operation("search_projects", { query: "<topic>" })`
3. `execute_operation("search_tasks", { query: "<topic>" })`
4. If the query mentions customers, feedback, pain points, or what users say →
   `execute_operation("search_feedback", { query: "<topic>" })`

`search_projects` results are discovery summaries only — not full Project Brain content. Pull full brain in step 4.

### 3. Present the context manifest

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
    5. AUTH-12 - Migrate OAuth tokens to new format       (in_progress, high)
    6. AUTH-13 - Update redirect handler                  (todo, medium)
    7. AUTH-14 - Write migration rollback script          (todo, medium)
    8. AUTH-15 - QA auth flow on staging                  (todo, low)

  Feedback (2):
    9. "SSO setup took 3 attempts before it worked"       (pain point, Acme Corp)
   10. "Love the new login flow, much faster"             (positive, Beta Co)

Which items should I pull into context? (numbers, "all", "docs only", or "skip")
```

**Rules:**

- Number every item sequentially across categories for easy selection.
- Show document type and approximate size (from search result metadata) when available.
- Show project lifecycle status and task count.
- Show task status and priority.
- Show feedback sentiment/theme and source customer/company when available.
- For tasks, show `slug - title` when available; otherwise show the task title.
- For projects and documents, show the readable name/title and URL when available; do not show raw Kestral IDs as
  handles.
- If a category has zero results, omit it from the display (Feedback only appears when step 2 ran `search_feedback`).
- If all searches return zero results: "I didn't find anything in Kestral matching that topic. Try different keywords or
  check that the relevant project/docs exist."

### 4. Pull selected content

Based on the user's selection:

#### Documents

For each selected document, call `execute_operation("get_document_content", { workContextId: "<id>" })`.

- Default read: up to 50,000 characters (the tool's default `length`).
- The response includes `isTruncated` (boolean) and `nextOffset` (number or null). If `isTruncated` is `true`, call
  again with `offset` set to `nextOffset`. Repeat until `isTruncated` is `false` or total loaded content exceeds **200
  KB** — then stop and note the truncation.
- Present each document's content in the chat with a clear header:

```
─── Auth Migration Plan (spec) ───

<document content here>

──────────────────────────────────
```

#### Projects

For each selected project, call `entity_lookup({ id: "<projectId>", type: "project" })`. The response includes Project
Brain knowledge in the `knowledge` field (goals, blockers, next steps) when generated. If `hasKnowledge` is false, note
that brain is unavailable or still building (`brainGenerationStatus`).

For brain-only when you already have a project ID and do not need project metadata, use
`execute_operation("get_project_brain", { projectId: "<projectId>" })` instead.

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

For each selected task, call `entity_lookup({ id: "<taskId>", type: "task" })`.

Present task details in the same format as the `/kestral:tasks` drill-down view (see `kestral-tasks/SKILL.md` step 3).

#### Feedback

Feedback items are already loaded from step 2's `search_feedback` results. Present each selected item:

```
─── Feedback: "SSO setup took 3 attempts before it worked" ───

  Source:     Acme Corp
  Sentiment:  pain point
  Theme:      authentication friction
  Created:    2026-06-15

───────────────────────────────────────────────────────────────
```

Show source (customer/company), sentiment, theme/tags, and date when available from the search result metadata.

### 5. Summarize

After pulling content, confirm what was loaded:

> Loaded 3 documents (~27 KB), 1 project, and 4 tasks into context. You can now ask me questions about them.

The agent now has this content in its conversation context and can reason about it in subsequent messages.

## Limits

- **Per-document cap:** 200 KB of text content. If a document exceeds this, load the first 200 KB and note: "Document
  truncated at 200 KB. Use `get_document_content` with `offset` to read further."
- **Total context budget:** If the user selects "all" and total content would exceed **500 KB**, warn before loading:

  > That's ~620 KB of content, which may reduce available context for our conversation. Load anyway, or pick specific
  > items?

  Proceed only if the user confirms.

## Error handling

| Failure                                                  | Message                                                                                                            |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Auth failure (401, unauthorized, or `Not authenticated`) | Guide the user to authenticate through their app's UI (see Prerequisites). The agent cannot handle OAuth directly. |
| Document not found                                       | "Selected document not found — it may have been deleted. Skipping."                                                |
| Search returned error                                    | "Search failed: `<error>`. Try again or check that the MCP server is connected (`/mcp`)."                          |
