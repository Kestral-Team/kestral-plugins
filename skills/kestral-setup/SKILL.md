---
name: kestral-setup
description: Authenticate with Kestral and organize local files plus connected-tool context into one or more Kestral projects. Use only when the user explicitly runs setup or asks to onboard, organize, or import work into Kestral.
---

# Setup

Authenticate with Kestral, inspect whatever sources the user provides, propose a small active-workstream taxonomy, and
create one or more Kestral projects with relevant documents, tasks, and Project Brain generation.

Setup is not limited to local folders. It can work from local files, GitHub, Linear, Jira, Notion, Google Drive, Slack,
and any other connected tool available in the chat. If the user only says they are not organized yet, help them get
organized by inspecting available sources and proposing a focused starting structure.

## Prerequisites

**Kestral** must show as **connected** with `upload_document` in the tool list — including Cowork. If missing, reconnect
in the client; do not send users to another app for local uploads.

## Workflow

### 0. Preflight

Run before any Kestral MCP call. Stop on failure; exact messages in `docs/manifest-copy-spec.md`.

**Kestral tools (all hosts)** — Confirm `upload_document` / `kestral_*` in this thread (`/mcp`). If absent → **MCP not
connected** (host-specific bullets). Codex: **Kestral** server required — `node_repl` is not the bridge.

### 1. Authenticate

Call `whoami` to confirm the Kestral MCP connection is active. OAuth opens the browser automatically on first use if
needed. If it fails, tell the user to reconnect the MCP server in client settings and retry.

Do not call write MCP tools until authentication succeeds.

### 2. Frame broad sources

Open with this framing:

> Welcome to Kestral. I can help turn scattered files, tasks, and connected tool data into organized Kestral projects
> so you and your team can stay on track automatically.
>
> I can work from local files, GitHub, Linear, Jira, Notion, Google Drive, Slack, and any other connected tool available
> in this chat. Give me whatever you have: a folder, a repo, a task system, a few links, or just "I'm not organized
> yet," and I'll propose a starting structure with projects, documents, tasks, and Project Brains.

Accept any useful source input:

- Local folders or explicit local file paths.
- Repositories or repo links.
- Connected task systems such as Linear, Jira, GitHub Issues, Asana, ClickUp, or Shortcut.
- Connected document systems such as Notion, Google Drive, Slack, Confluence, and other linkable sources.
- User buckets: explicit project names, goals, work areas, teams, or outcomes the user wants to organize around.

Use lightweight steering prompts when they fit:

> Want me to use your task system as the main signal, or do you already have buckets in mind?

> I found active work in Linear and GitHub, plus docs in Drive. I'll use those unless you want to limit scope.

> I can create the recommended projects, just the top few, or let you rename/split/merge first.

> This is a curated first pass. I'll import the most relevant context now and leave the rest available to add later.

For read-only source inspection, tell the user what is being checked and proceed. Do not ask for per-source approvals.

### 3. Inventory sources

Inspect independent sources in parallel when possible. Dispatch sub-agents for independent source families when the host
supports it; otherwise use parallel tool calls for independent reads. Keep sub-agent outputs compact: source name,
candidate workstreams, task metadata, document titles/paths/URLs/IDs, confidence notes, and failures. Do not load huge
task or document bodies into main context when metadata, paths, URLs, or IDs are enough.

Use these source-specific helpers and patterns:

| Source family | Guidance |
| --- | --- |
| Local files | Use `scan-folder/SKILL.md` for folders and explicit file lists. Keep file paths, sizes, sampled titles, candidate themes, and notable omissions. |
| Task systems | Use `scan-tasks/SKILL.md` for Linear, Jira, GitHub Issues, and similar tools. Prefer open, in-progress, recently updated, high-priority, or recently completed work. |
| Document systems | Discover Notion, Google Drive, Slack, Confluence, and other linkable sources through available MCP tools. Keep canonical URLs for `link_external_document`; content text is only a fallback snapshot. |
| User buckets | Treat user-provided project names, goals, work areas, and outcomes as the taxonomy unless the user asks you to infer alternatives. |
| Repositories | Use repo metadata, issue links, README/docs references, milestones, labels, and recent activity to support task and document signals. |

If the user scoped sources, honor that scope. If they only said they are not organized yet, inspect available connected
task and document sources plus obvious local context from the conversation, then propose a focused starting structure.

If a connected source read fails, mark that source skipped and continue with the other sources. If all usable sources are
missing or unreadable, ask one targeted question that would unblock setup.

### 4. Infer active workstreams

Default to active workstreams, not archive categories or source-system silos.

Taxonomy rules:

- User-provided buckets take precedence. Map available tasks and documents into those buckets first.
- Task systems are the strongest inferred signal because they encode projects, epics, milestones, labels, boards,
  assignees, status, priority, and recency.
- Documents support, refine, or challenge the task structure. Use doc titles, folder names, links, sampled content, and
  recency to attach evidence or reveal missing workstreams.
- If task and document signals disagree, anchor on active tasks and note the ambiguity in the manifest.
- Avoid creating projects for stale, purely historical, or low-evidence themes unless the user explicitly asks.

Project count rules:

- Recommend 1-3 projects by default.
- Allow up to 5 when workstreams are clearly distinct.
- Do not propose more than 5 projects by default; show extra candidates separately as workstreams to revisit later.
- If the user asks for more than 5 projects, allow it with a warning that starting with fewer usually creates a clearer
  operating model.
- If signal is weak, ask one targeted question before creating projects.

Default import is curated, not capped. Select the most relevant representative tasks and documents for the first pass.
If the user asks for more or all matching tasks/documents, import more or all in batches within the approved projects.

### 5. Render a multi-project manifest

Show proposed Kestral projects, not a source dump. Each proposed project includes:

- Title and short description.
- Rationale: task project, label, epic, milestone, board, recent activity, repeated document theme, or user bucket.
- Selected tasks grouped by source, with priority/status annotations when available.
- Selected documents from local files and connected tools, with `[local]` or `[<source>]` labels.
- Coverage counts, such as "12 tasks selected, 43 more matching" or "8 docs selected, 96 more candidates."
- Confidence and ambiguity notes, such as "High confidence from Linear project and matching Drive docs."

Render compactly:

```md
Proposed projects

1. Billing Automation
   Description: Consolidates active billing workflow work and supporting implementation docs.
   Rationale: Linear project, recent GitHub issues, and matching Drive design docs.
   Selected tasks:
     - Fix invoice retry state [linear, high]
     - Add webhook replay tests [github, medium]
   Selected documents:
     - billing-architecture.md [local]
     - Billing rollout notes [google-drive, linked]
   Coverage: 12 tasks selected, 43 more matching; 8 docs selected, 96 more candidates.
   Confidence: High. Ambiguity: one Slack thread may belong to Support Ops.

Extra candidates to revisit later
- Legacy billing cleanup: stale tasks and low recent activity.
```

Make clear that the curated manifest is a starting import, not a hard limit:

> This is a curated first pass. I'll import the most relevant context now and leave the rest available to add later.

### 6. Manifest checkpoint

Wait for user input after rendering the manifest. Supported commands:

| Command or intent | Effect |
| --- | --- |
| `proceed` / `approve` / `create these` | Create selected projects and import selected context |
| `only create <project>` | Deselect other proposed projects |
| `skip <project>` | Remove a proposed project from this run |
| `rename <project> to <new title>` | Update a proposed project title |
| `split <project>` | Ask one focused follow-up and split into clearer workstreams |
| `merge <project A> and <project B>` | Combine proposed projects and their selected context |
| `move <item> to <project>` | Move a selected task or document between proposed projects |
| `use these buckets: <list>` | Switch to user-led taxonomy and remap sources |
| `import more <source> into <project>` | Expand import scope for that project/source |
| `import all matching <tasks/documents>` | Switch that project/source to bulk import mode |
| `cancel` / `stop` | Exit cleanly without Kestral write calls |

Re-render the manifest after edits. Do not add redundant approval loops after the user approves normal curated setup.

Ask for explicit confirmation only when:

- The user requests a large bulk import.
- The run would create more than 5 projects.
- The scope is ambiguous or risky enough that a mistaken import would be hard to unwind.

For large writes, confirm scope in one concise message, such as:

> This will import 437 tasks and 82 documents into 3 projects. Proceed?

Do not ask separate confirmations for every project, source, document batch, or task batch.

### 7. Apply selected projects and imports

On approval, apply each selected project. Use parallel write calls only where writes are independent and the host allows
it; otherwise proceed sequentially with compact progress updates. Always preserve successful project URLs.

For each selected project:

1. Call `create_project` with the project title, description, and lifecycle status when appropriate. Store `projectId`
   and `url`.
2. Upload selected local documents with `upload_document`.
3. Link selected external documents with `link_external_document`.
4. Create selected tasks with `create_tasks`.
5. Trigger `trigger_brain_build` for that project.

For `upload_document`, pass `filePath` for one local file or `filePaths` for multiple local files when the tool schema
supports it. If the host exposes only the legacy single-file schema, call `upload_document` once per selected local file.

Local uploads:

- Use absolute `filePath` values only.
- Do not read file bytes into the agent or pass content in the tool call.
- If `.doc` or `.docx` files require conversion in the current host, convert only when needed; if conversion fails,
  skip those files when other documents remain or stop that project's local upload if no local documents can be used.
- Track per-file success and failure.

External documents:

- Use `link_external_document` for documents with canonical source URLs.
- Pass `url`, `title`, `projectId`, and fallback `content` when available.
- Never reproduce external content through `create_document`; that loses provenance and breaks autosync.
- Track `resolutionStatus`. A `pending` result is partial success: the snapshot is linked, but the matching Kestral
  integration should be connected for live autosync.

Tasks:

- Use `create_tasks` with the selected task records for the project.
- Preserve source labels in task descriptions or metadata when available.
- For bulk task imports, batch by source and project, summarize progress, and continue on item-level failures when safe.

Project Brain:

- Call `trigger_brain_build` per project after documents and tasks are attached.
- Brain failures do not invalidate project creation or imported context.

### 8. Present results

Return a compact summary:

- Successful project titles and URLs.
- Documents linked/uploaded per project, including pending external links.
- Tasks created per project and source.
- Project Brain status per project.
- Skipped sources and item or batch failures.

Always return successful project URLs when any project creation succeeded, even if imports or Project Brain failed.

If one or more linked docs returned `resolutionStatus: "pending"`, add one line naming the distinct sources and pointing
the user to connect them in Kestral:

> I linked your Notion and Google Drive docs from saved snapshots. Connect those integrations in Kestral
> (**Workspace Settings → Integrations**) and they'll autosync to the latest version.

If brain generation was enqueued, say:

> Brain is generating — usually 1-2 minutes.

If Project Brain is not enabled:

> Project created. Project Brain isn't enabled for this workspace — ask your admin to turn it on, then open the project
> and click Generate.

If Project Brain fails:

> Project created. Brain generation couldn't start. Open the project and click Generate to retry.

### 9. Follow-up options

After setup, offer concise next actions without auto-running them:

> Want me to keep going? I can add more context, help clear blockers, or help map the remaining candidate workstreams.

When the user chooses:

| User intent | Do this |
| --- | --- |
| Add more context | Scan or link the new sources, attach them to the relevant existing project, and rerun `trigger_brain_build`. |
| Help clear blockers | Use Kestral task tools to inspect open project work and help the user pick the next blocker. |
| Map remaining candidates | Return to the extra candidate workstreams and ask one targeted question if the next split is unclear. |

## Speed and Context Rules

- Use sub-agents for independent source scans and import preparation when available.
- Use parallel tool calls for independent reads.
- Keep sub-agent outputs compact.
- Do not load huge task or document bodies into main context when metadata, paths, URLs, and IDs are enough.
- Inform before acting, then avoid redundant approval loops.
- Ask explicit confirmation only for large bulk imports, creating more than 5 projects, or ambiguous/risky scope.
- Do not ask separate confirmations for every project, source, document batch, or task batch.

## Cancel Behavior

Before any write MCP tool has been called, `cancel` or `stop` exits cleanly. Confirm:

> Cancelled. No changes were made in Kestral.

After project creation or import writes have started, cancellation means stop future writes as soon as safely possible.
Do not start additional project creation, document upload/link, task creation, or Project Brain calls after cancellation.
Return a compact partial-results summary with:

- Projects already created, including successful project URLs.
- Documents already uploaded or linked.
- Tasks already created.
- Project Brain calls already started or skipped.
- Any selected projects, documents, or tasks not attempted because cancellation stopped the run.

## Error and Failure Handling

- Kestral auth or MCP failure stops setup before writes. Tell the user to reconnect the MCP server and retry.
- Missing `upload_document` stops local-file upload planning until Kestral is reconnected, but other non-local source
  inspection can still continue before writes.
- Connected source read failures skip that source and continue with remaining sources.
- If project creation fails for a proposed project, do not attempt imports for that project. Continue with other selected
  projects only when their writes are independent and the user-approved scope still makes sense.
- If project creation succeeds but some imports fail, always return successful project URLs plus a per-source failure
  summary.
- If a bulk import is requested, treat failures as item-level or batch-level and continue when safe.
- Project Brain failures do not invalidate imported work.
- Pre-write cancellation means no write MCP tools. Mid-run cancellation stops future writes and summarizes completed
  writes.

## Error Message Reference

Use `docs/manifest-copy-spec.md` for exact user-facing copy: preflight messages, error principles, partial-success
examples, and pending-link nudges. Adapt project counts, source names, item counts, and URLs to the actual run.
