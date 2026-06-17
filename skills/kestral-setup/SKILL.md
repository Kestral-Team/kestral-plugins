---
name: kestral-setup
description: Use when the user explicitly runs Kestral setup, asks to onboard, organize, or import work into Kestral, or wants projects created from connected tools, goals, repos, documents, or local files.
---

# Setup

Authenticate with Kestral, inspect whatever sources the user provides, propose a small active-workstream taxonomy, and
create one or more Kestral projects with relevant documents, tasks, and Project Brain generation.

Setup works from connected tools (Linear, Jira, GitHub, Notion, Google Drive, Slack, and others), user-provided goals,
repositories, and optionally local files. If the user only says they are not organized yet, help them get organized by
inspecting available sources and proposing a focused starting structure.

## Prerequisites

**Kestral** must show as **connected** with tools such as `whoami`, `create_project`, or `query_entities` in this
session. If missing, reconnect in the client.

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

### 0. Preflight

Run before any Kestral MCP call. Stop on failure; exact messages in `docs/manifest-copy-spec.md`.

**Kestral tools (all hosts)** — Confirm Kestral tools such as `whoami`, `create_project`, or `query_entities` in this
thread (`/mcp`). If absent → **MCP not connected**. Give the user the matching troubleshooting steps:

- **Claude Code Desktop / Claude Cowork:** Open **Customize → Kestral plugin → Connectors**, click **Install** on
  Kestral, then click **Add**. Once connected, run `/kestral:kestral-setup` again.
- **Claude Code CLI:** Open settings (gear icon or `/config`), go to **MCP Servers**, add or reconnect the **Kestral**
  server, then run `/kestral:kestral-setup` again.
- **Cursor:** Open **Settings → MCP Servers**, add or reconnect the **Kestral** MCP server, then retry.
- **Codex:** Open **Settings → MCP Servers**, add or reconnect the **Kestral** MCP server, then retry.

Do not block setup if upload tools are missing. Step 7 handles upload attempts gracefully — trying the best available
tool, offering egress fix instructions on failure, and falling back to `create_document` for text files. Project
creation, task import, and external doc linking work regardless of upload capability.

### 1. Authenticate

Call `whoami` to confirm the Kestral MCP connection is active. OAuth opens the browser automatically on first use if
needed. If it fails, tell the user to reconnect the MCP server in client settings and retry.

Do not call write MCP tools until authentication succeeds.

### 2. Frame broad sources

Open with this framing:

> Welcome to Kestral. I can help organize your work into Kestral projects so you and your team can stay on track
> automatically.
>
> Tell me what you're working on — a goal, a project you want to move over, or point me at where your context lives
> (Linear, Jira, GitHub, Notion, Google Drive, Slack, files, or anything else). I'll propose a starting structure with
> projects, tasks, and Project Brains.

Accept any useful source input:

- User buckets: explicit project names, goals, work areas, teams, or outcomes the user wants to organize around.
- Connected task systems such as Linear, Jira, GitHub Issues, Asana, ClickUp, or Shortcut.
- Connected document systems such as Notion, Google Drive, Slack, Confluence, and other linkable sources.
- Repositories or repo links.
- Files or folders the user mentions — handle them when offered, but do not proactively ask for local paths.

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
| User buckets | Treat user-provided project names, goals, work areas, and outcomes as the taxonomy unless the user asks you to infer alternatives. |
| Task systems | Use `scan-tasks/SKILL.md` for Linear, Jira, GitHub Issues, and similar tools. Prefer open, in-progress, recently updated, high-priority, or recently completed work. |
| Document systems | Discover Notion, Google Drive, Slack, Confluence, and other linkable sources through available MCP tools. Keep canonical URLs for `link_external_document`; content text is only a fallback snapshot. |
| Repositories | Use repo metadata, issue links, README/docs references, milestones, labels, and recent activity to support task and document signals. |
| Local files | Only when the user explicitly provides a folder or file paths. Use `scan-folder/SKILL.md` for folders and explicit file lists. Treat files as evidence first: inspect representative document content when possible, keep file paths, sizes, sampled titles, candidate themes, and notable omissions, then decide whether each file should also be uploaded. |

If the user scoped sources, honor that scope. If they only said they are not organized yet, inspect available connected
task and document sources, then propose a focused starting structure. Do not proactively scan local folders unless the
user mentions them.

If a connected source read fails, mark that source skipped and continue with the other sources. If all usable sources are
missing or unreadable, ask one targeted question that would unblock setup.

### 4. Infer active workstreams

Default to active workstreams, not archive categories or source-system silos.

Documents are flexible evidence. A document may be:

- A source to inspect so the agent can understand the user's work and propose an organization.
- A local upload or external link to attach to a Kestral project.
- **Inline text** pasted in chat (Slack thread, summary, notes) — attach with `create_document` and `projectId`, not the
  project description field.
- Both evidence and project context when it is useful for Project Brain.

For a small document set, inspect enough content to understand the work at a high level before proposing projects. For a
large document set, sample representative documents, summarize coverage, and let the user steer expansion. If only
filename, path, metadata, or a failed extraction is available, say that clearly and do not present filename-only guesses
as if the contents were understood. Ask one focused question only when the evidence is too thin or risky for a useful
manifest.

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

Use readable labels throughout the manifest: document names, source labels, task titles, and priority labels. External task IDs are provenance/debug details only; do not show them unless the user asks.

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

Render the manifest for visibility, then proceed — do not block on a separate manifest approval when the host already
prompts for write-tool permission (Claude Code, Claude Cowork, Cursor, Codex with tool permissions enabled).

Then continue to step 7 unless the user sends an edit or cancel command first. Supported commands mirror
`docs/manifest-copy-spec.md`. If an edit target is ambiguous in a multi-project manifest, ask one focused clarification
before applying it:

| Command or intent | Effect |
| --- | --- |
| `ok` / `yes` / `go` / `create these` | Proceed to create selected projects and import selected context |
| `revise` | Edit the manifest before proceeding (same as edit commands below) |
| `remove <file>` | Remove a specific local file from the selected document list |
| `add <path>` | Validate the path, stat its byte size, and add it to the selected local documents |
| `remove <source> documents` | Remove all selected documents from a source, such as Notion or Google Drive |
| `skip tasks` | Remove selected tasks from this run so no tasks are imported |
| `title: <new>` / `change title <new>` | Override a proposed project title; ask if the target project is unclear |
| `description: <new>` / `change description <new>` | Override a proposed project description; ask if the target project is unclear |
| `only create <project>` | Deselect other proposed projects |
| `skip <project>` | Remove a proposed project from this run |
| `rename <project> to <new title>` | Update a proposed project title |
| `split <project>` | Ask one focused follow-up and split into clearer workstreams |
| `merge <project A> and <project B>` | Combine proposed projects and their selected context |
| `move <item> to <project>` | Move a selected task or document between proposed projects |
| `use these buckets: <list>` | Switch to user-led taxonomy and remap sources |
| `import more <source> into <project>` | Expand import scope for that project/source |
| `import all matching <tasks/documents>` | Switch that project/source to bulk import mode |
| `look at <folder> instead` / `change folder <path>` | Re-scan a new folder and remap the proposed taxonomy |
| `cancel` / `no` / `stop` | Exit cleanly without Kestral write calls |

Re-render the manifest after edits. Do not add redundant approval loops — the host's tool-permission prompt is the
approval gate for normal curated setup.

**Hosts without per-tool permission prompts** (agents that auto-run MCP writes with no confirmation): wait for explicit
`ok` / `create these` before calling any write MCP tool. Ask: "Okay to proceed? ok/revise/cancel"

Ask for explicit confirmation and wait before writes when:

- The user requests a large bulk import.
- The run would create more than 5 projects.
- The scope is ambiguous or risky enough that a mistaken import would be hard to unwind.
- The host does not provide per-tool permission prompts.

For large writes, confirm scope in one concise message, such as:

> This will import 437 tasks and 82 documents into 3 projects. Okay to proceed? ok/revise/cancel

Do not ask separate confirmations for every project, source, document batch, or task batch.

### 7. Apply selected projects and imports

Apply each selected project after the manifest checkpoint (or after explicit ok for no-permission hosts). Use parallel
write calls only where writes are independent and the host allows it; otherwise proceed sequentially with compact progress
updates. Always preserve successful project URLs.

For each selected project:

1. Call `create_project` with the project title, description, and lifecycle status when appropriate. Store `projectId`
   and `url`.
2. Upload selected local documents using the upload strategy detected in preflight (see below).
3. Link selected external documents with `link_external_document`.
4. For **pasted inline content** in the manifest or conversation (Slack export text, summaries, notes with no file path
   and no external URL), call `create_document` with `{ title, content, projectId }` — not `upload_document` or
   `project_management`.
5. Create selected tasks with `create_tasks`.
6. Trigger `trigger_brain_build` for that project.

#### Local document upload

Follow the document upload workflow in `upload/SKILL.md` (Steps 1–2 for upload and egress recovery, plus the fallback
for creating documents from file content when upload isn't possible).

Report upload failures per-file; do not pre-declare hard limits. Skip rejected files and continue.

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

Present created projects, linked documents, uploaded documents, and imported tasks by readable title/name and URL when
available.

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
- Inform before acting, then avoid redundant approval loops — show the manifest and proceed on normal curated setup;
  the host's tool-permission prompt is the write approval gate.
- Ask explicit confirmation only for large bulk imports, creating more than 5 projects, ambiguous/risky scope, or
  hosts without per-tool permission prompts.
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

- Auth/MCP failure → stop before writes; reconnect and retry.
- Upload failure (egress) → give platform-specific egress fix steps; if user can't fix, fall back to `create_document`.
- No upload tools → text/markdown via `create_document`; binary files skipped with manual-upload message.
- Source read failure → skip that source, continue with others.
- Project creation failure → skip imports for that project, continue with others.
- Partial import failure → always return successful project URLs alongside failures.
- Brain failures → non-fatal; report and continue.
- Cancellation → stop future writes; summarize what completed.

## Error Message Reference

Use `docs/manifest-copy-spec.md` for exact user-facing copy: preflight messages, error principles, partial-success
examples, and pending-link nudges. Adapt project counts, source names, item counts, and URLs to the actual run.
