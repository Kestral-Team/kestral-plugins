---
name: kestral-setup
description: Use when the user explicitly runs Kestral setup, asks to onboard, organize, or import work into Kestral, or wants to create a Kestral project with a Project Brain from connected tools, goals, repos, documents, or optional local files.
---

# Setup

Help the user set up a **Kestral project with a Project Brain** — a living summary of their work for themselves, their
coding agents, and their team. Setup inspects connected tools and user-stated goals, proposes projects, imports context,
and generates brains they can work from immediately. Local files only when the user offers them.

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
- **Codex:** Open **Settings → MCP Servers**, add or reconnect the **Kestral** MCP server, then run `$kestral-setup`
  in a **new thread**.

Do not block setup if upload tools are missing. Step 7 handles upload attempts gracefully — trying the best available
tool, offering egress fix instructions on failure, and falling back to `create_document` for text files. Project
creation, task import, and external doc linking work regardless of upload capability.

### 1. Authenticate

Call `whoami`. If it succeeds, proceed. If it fails (401 / unauthorized), guide the user through their host's UI to
authenticate — the agent cannot handle OAuth callbacks or generate auth links directly:

- **Claude Code Desktop / Claude Cowork:** Open **Customize → Kestral** (under Personal plugins) **→ Connectors**,
  click **Install** on Kestral, then click **Add**. A browser opens for sign-in.
- **Claude Code CLI:** Run `/mcp`, find **Kestral**, and reconnect it. Follow the browser prompt to sign in.
- **Codex:** Open **Settings → MCP Servers**, find **Kestral**, click **Authenticate**. Sign in via the browser that
  opens. Run `$kestral-setup` in a **new thread** after authenticating.
- **Cursor:** Open **Settings → MCP Servers**, find **Kestral**, click **Authenticate** or **Connect**. If `mcp_auth`
  is available, the agent can call it to trigger the browser flow.

> Once you've signed in, ask me to continue.

Do not call other Kestral tools until `whoami` succeeds.

### 1.5. Existing project detection

After `whoami` succeeds, call `query_entities({ type: "projects", query: "all projects", explanation: "Check for existing projects before setup" })`
to see whether the workspace already has projects.

| Condition | Behavior |
| --- | --- |
| No projects | Continue to step 2 (connected-sources opener). |
| 1+ projects | Run the **prioritized work snapshot** (below), then show the three next-step options. |

#### Prioritized work snapshot (when projects exist)

Before asking what the user wants to do, give them a **prioritized look at their work** — do not jump straight to
"create a new project?" or source collection.

Run in parallel when the host supports it:

1. **`get_daily_brief`** — personal summary of what changed across projects (urgent items, blockers, stale work, project
   mentions). If the brief is generating, say so briefly and continue with project brains.
2. **`entity_lookup({ type: "project_brain", id: "<projectId>" })`** for the **top 2–3 projects** to highlight:
   - Prefer projects named or prioritized in the daily brief.
   - Otherwise pick the most recently updated projects from the `query_entities` project list.
   - Keep each brain digest to **2–3 bullets** (goals, blockers, recent changes) — do not dump full brain text.
   - If `brainGenerationStatus` is `queued` or `running`, say the brain is building (~1–2 min).
   - If no brain exists, note it and link the project URL — do not block the flow.

Render compactly, then show the three options:

> I found [N] Kestral projects in your workspace, each with a **Project Brain** that stays in sync as you and your
> agents work.
>
> **Your prioritized work**
>
> *[2–4 bullets from `get_daily_brief` — what changed, what's urgent, what needs attention today]*
>
> **From your Project Brains**
>
> 1. [Project Name](project-url)
>    - *[2–3 bullets from brain: goals, blockers, recent changes — or "Brain building…" / "No brain yet"]*
> 2. ...
> …and [N] more projects. *(when 4+ total)*
>
> **You can get started right now:**
> - **Pick a task from above** and start working — I can set it in progress and help here
> - **Plan your day** — run `/kestral:plan-day` (or `$kestral-plan-day` in Codex) for a prioritized plan across all
>   your projects
>
> **Or set up more:**
> - **Add more context** to a project — pull new docs or tasks from connected apps and refresh the brain
> - **Create a new project** — set up a Kestral project with a brain from Linear, Jira, Notion, Drive, Granola, or
>   other connected apps

Do not ask for sources or a manifest until the user picks **Add more context** or **Create a new project**.

**Routing:**

| User choice | Next step |
| --- | --- |
| Pick a task / start working | Help them start (set task in progress, outline steps). Introduce Sync + plan-day + end-day if not yet mentioned. |
| Plan my day / explore | Enter the **explore and work** flow (below). |
| Add more context to [project] | Enter the **enrich existing project** flow (below). Skip step 2 opener; frame around "what new context should we add?" |
| Create a new project | Continue to step 2 (connected-sources opener). Frame as setting up a new Kestral project with a brain. |

#### Explore and work flow

When the user wants to explore existing projects rather than create or enrich:

1. If the **prioritized work snapshot** (step 1.5) already ran, do not repeat the full project list — confirm which
   project to focus on, or pick the top project from the brief/brain highlights if the user says "just help me get started."
2. Otherwise share project links and brain highlights (same pattern as step 1.5).
3. Suggest visiting the Project Brain link, then **plan your day** — invoke `plan-day/SKILL.md` or tell the user to run
   **`/kestral:plan-day`** (Claude Code / Cowork) or **`$kestral-plan-day`** (Codex). Pull daily brief, calendar, and
   task state for prioritized work; help them pick a task from the plan.
4. After plan-day (or once they start a task), introduce the **ongoing skills** (suggest, do not auto-run):

   > **Skills that keep your project in sync** (you only set these up once):
   >
   > - **Plan day** — `/kestral:plan-day` or `$kestral-plan-day` — morning prioritization from your brief, calendar,
   >   and tasks (what you just ran, or rerun anytime).
   > - **Kestral Sync** — `/kestral:sync` or `$kestral-sync` for a manual sync; for automatic updates, install the
   >   ambient sync rule once (`sync/README.md` — paste the snippet into `AGENTS.md` or `CLAUDE.md`). After that, progress
   >   comments, status changes, and PR links flow back on push and phase completion — you don't need to keep saying
   >   "kestral sync."
   > - **End day review** — `/kestral:end-day-review` or `$kestral-end-day-review` — when you wrap up, reconciles what
   >   got done, updates task status in the project, and sets tomorrow's priorities.

5. Stay focused on the project — suggest adding context only when the user asks.

#### Enrich existing project flow

When the user picks an existing project to enrich:

1. Store the selected project's `projectId` and `url` — do **not** call `create_project`.
2. Open with: "What new context should we add to [Project Name]? Point me at connected apps — Linear, Jira, Notion,
   Drive, Granola notes, local files/folders — or describe what changed."
3. Run steps 3–6 (inventory, infer workstreams, manifest, checkpoint) scoped to **additions only** — new docs, tasks, or links for that project. The manifest may be a single-project "add to existing" view rather than multi-project creation.
4. In step 7, skip `create_project`. Upload/link documents and create tasks against the existing `projectId`. Call `trigger_brain_build` for that project after new context is attached.
5. Continue to step 8 (results) and step 9 (guided journey).

If the user cancels during enrich, follow the same cancel behavior as the main flow.

### 2. Frame context sources (connected-first)

#### What setup delivers (say this explicitly)

Before asking for sources, frame what they're building toward — it explains **why** sources matter.

> **What you'll get:** A **Kestral project with a Project Brain** — a living, AI-generated summary of your work that:
>
> - Gives **you** prioritized context when you start your day
> - Gives **your coding agents** the same shared understanding (via Kestral MCP)
> - Keeps **your team** aligned without status meetings — the brain updates as tasks, docs, and progress change
>
> The apps and docs you point me at (Linear, Jira, Notion, Drive, Granola, etc.) **feed that brain**. I'll create a
> Kestral project, import the most relevant tasks and documents, and generate a Project Brain you can work from
> immediately — for yourself, your agents, and your team.

#### Output format

Use **plain conversational prose** — ask questions in normal sentences and let the user reply in chat. Avoid rendering
setup as a card grid, source tiles, button panels, labeled form fields, or other custom UI that the host doesn't
natively support.

#### Local files

Setup leads with connected tools and goals. Local files are just another source the user can mention — handle them via
`scan-folder/SKILL.md` when they do. Use words like "include" or "add" rather than "scan" in user-facing copy.

#### 2a. Surface what's available

After auth (and any existing-project routing), inspect what source tools are loaded in this session — task systems
(Linear, Jira, GitHub Issues, Asana, …), document systems (Notion, Google Drive, Confluence, Slack), Granola, and
other MCP connectors. Use that inventory to tailor the opener; do not interrogate the user source-by-source.

Open with this framing (adapt connector names to what's actually loaded). Lead with **what they'll get**, then ask for
sources:

> Welcome to Kestral. I'll help you set up a **Kestral project with a Project Brain** — a living summary of your work
> that you, your coding agents, and your team can work from immediately. It stays in sync as tasks, docs, and progress
> change.
>
> **Where does your context live?** The sources you name become the project's foundation and feed the brain. For
> example: a Linear project, Jira board, Notion or Google Drive docs, Confluence pages, Slack threads, Granola notes,
> local files/folders, or describe a goal.
>
> Example: "Use my Linear Auth project and matching Drive docs" or "I'm launching billing automation — pull Jira and
> Notion."

If connectors are loaded, mention them briefly once (e.g. "I see Linear and Google Drive connected here — say which to
use, or describe your goal and I'll pick signals."). If none besides Kestral are loaded, skip the inventory line and
focus on goals; the user can still paste content or add integrations later.

If the user doesn't have existing context in any app — just an idea or goal — that's enough. Help them refine it into a
project description, create the project, and seed a document with their notes so the brain has something to work from.
They can always add more context later.

Accept any useful source input:

- User buckets: explicit project names, goals, work areas, teams, or outcomes the user wants to organize around.
- Connected task systems such as Linear, Jira, GitHub Issues, Asana, ClickUp, or Shortcut.
- Connected document systems such as Notion, Google Drive, Slack, Confluence, Granola, and other linkable sources.
- Repositories or repo links.
- Files or folders the user mentions.

Use lightweight steering prompts when they fit:

> Want me to use your task system as the main signal, or do you already have buckets in mind?

> I found active work in Linear and GitHub, plus docs in Drive. I'll use those unless you want to limit scope.

> I can create the recommended projects, just the top few, or let you rename/split/merge first.

> This is a curated first pass. I'll import the most relevant context now and leave the rest available to add later.

For read-only source inspection, tell the user what is being checked and proceed — one mention of connected sources is
enough.

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
| Document systems | Use `link_external_document` for sources with recognized URLs (Notion, Google Drive, Slack, Confluence). For other document sources like Granola, pull the content via MCP and use `create_document`. |
| Repositories | Use repo metadata, issue links, README/docs references, milestones, labels, and recent activity to support task and document signals. |
| Local files | User-initiated. Use `scan-folder/SKILL.md` when the user provides a folder or file paths. Treat files as evidence first: inspect representative content when possible, keep file paths, sizes, sampled titles, candidate themes, and notable omissions, then decide whether each file should also be uploaded. |

If the user scoped sources, honor that scope. If they only said they are not organized yet, inspect available connected
task and document sources, then propose a focused starting structure.

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
- Prefer 1–3 projects by default; up to 5 when workstreams are clearly distinct. Show extras as candidates to revisit.
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
| `look at <folder> instead` / `change folder <path>` | Switch to a different local folder and remap the proposed taxonomy |
| `cancel` / `no` / `stop` | Exit cleanly without Kestral write calls |

Re-render the manifest after edits. The host's tool-permission prompt is the approval gate for normal curated setup.

**Hosts without per-tool permission prompts** (agents that auto-run MCP writes with no confirmation): wait for explicit
`ok` / `create these` before calling any write MCP tool. Ask: "Okay to proceed? ok/revise/cancel"

Ask for explicit confirmation and wait before writes when:

- The user requests a large bulk import.
- The run would create more than 5 projects.
- The scope is ambiguous or risky enough that a mistaken import would be hard to unwind.
- The host does not provide per-tool permission prompts.

For large writes, confirm scope in one concise message, such as:

> This will import 437 tasks and 82 documents into 3 projects. Okay to proceed? ok/revise/cancel

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

- Use `link_external_document` for documents with canonical source URLs. Pass `url`, `title`, `projectId`, and fallback
  `content` when available. Prefer linking over reproducing content via `create_document` — linked docs keep provenance
  and support autosync.
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

> Your **Kestral project** is created and the **Project Brain** is generating — usually ready in **30 seconds to 2
> minutes**. [Project Name](project-url)
>
> **Next: start working from the brain.** Once it's ready, I'll pull **blockers and next steps** from your Project Brain
> here so you can pick one and get started — you don't need to leave the chat.
>
> Say **"brain's ready"** or **"what should I work on?"** when you want me to fetch it, or I can check in a moment if
> you'd like.

Then **always** continue to the **Start from Project Brain** prompt below — do not end the message after import/brain
status alone (e.g. do not stop after listing due-date mappings without a next-step ask).

#### Start from Project Brain (required after create or enrich)

After reporting creation/enrichment results, walk the user into immediate work. Each beat is a suggestion — do not
auto-run writes without approval, but **do** proactively offer to pull the brain.

1. **When brain may be ready:** Call `entity_lookup({ type: "project_brain", id: "<projectId>" })`.
   - If `brainGenerationStatus` is `queued` or `running`, tell the user it's still building and offer to retry when they
     say "brain's ready" (or retry once after ~30s if the host supports waiting).
   - If a summary exists, extract **blockers**, **next steps**, and **urgent/open work** — keep to 3–5 bullets, not the
     full brain dump.
2. **Present and ask:**

   > **From your Project Brain — here's what to tackle:**
   >
   > - *[blocker or next step 1]*
   > - *[blocker or next step 2]*
   > - ...
   >
   > **You can start right now:** pick one and I can set it **in progress** and help you work it here.
   > **Or:** run `/kestral:plan-day` for a full prioritized plan across your projects.

3. If the brain is empty or still building and the project has imported tasks, fall back to open/high-priority tasks via
   `query_entities` scoped to the project — still ask which to start on.
4. After the user picks work, help them start (set task in progress, outline first steps).

   **GitHub integration nudge (coding tasks only):** If the task the user picked is code-related (mentions code, a repo,
   a branch, PR, implementation, engineering, etc.), call `kestral_integration_status({ service: "github" })`. If
   `connected` is false, suggest connecting it — the response includes a workspace-scoped `deepLink` URL:

   > **Connect GitHub** so **Kestral Sync** can link PRs to this task and post progress as you push — your Project
   > Brain and team stay current automatically as you code: [Connect GitHub](deepLink-from-response)
   >
   > You can still work without it — Sync will post progress comments, but PR linking needs the GitHub integration.

   If GitHub is already connected, skip the nudge entirely. Then mention Sync briefly (set up once) and continue to
   step 9 for plan-day / end-day skills if not yet introduced.

If multiple projects were created or enriched, run this flow for the primary project first (or ask which project to focus
on), then offer the others.

If Project Brain is not enabled:

> Project created. Project Brain isn't enabled for this workspace — ask your admin to turn it on, then open the project
> and click Generate.

If Project Brain fails:

> Project created. Brain generation couldn't start. Open the project and click Generate to retry.

### 9. Guided onboarding journey

After step 8 (including **Start from Project Brain**), walk the user through ongoing skills if they haven't started a
task yet. Each beat is a **suggestion** — never auto-run the next skill. Present in order; user can skip any beat.

#### 9a. Explore Project Brain (if not already pulled in step 8)

> Open [Project Name](project-url) to see the full brain, or ask me to **pull blockers and next steps** here anytime.

If blockers were not yet fetched, run `entity_lookup({ type: "project_brain", id })` and ask which item to start on.

When you're back from the project page, run **`/kestral:plan-day`** (or `$kestral-plan-day` in Codex) for broader day
prioritization across projects.

If the user came from **explore and work** (step 1.5) with no new imports, skip re-listing projects — focus on plan-day
and ongoing skills from the snapshot already shown.

#### 9b. Plan My Day

> Run **`/kestral:plan-day`** (Claude/Cowork) or **`$kestral-plan-day`** (Codex) — it pulls your daily brief, calendar,
> and task state into a realistic plan with focus blocks. Pick a task from the plan and start work.

#### 9c. Kestral Sync (set up once)

> To keep your project and Project Brain updated as you work, set up **Kestral Sync** once — see `sync/README.md` and
> paste the ambient snippet into your project's `AGENTS.md` or `CLAUDE.md` (Codex/Claude) or install the Cursor rule.
> After that, progress comments, status changes, and PR links flow back automatically on push and phase completion —
> you don't need to keep invoking sync. Use **`/kestral:sync`** or **`$kestral-sync`** only when you want a manual
> "sync now."

#### 9d. End day review

> When you wrap up, run **`/kestral:end-day-review`** (Claude/Cowork) or **`$kestral-end-day-review`** (Codex). It
> reviews what got done, updates task status in your project, reconciles project state, and sets tomorrow's priorities.

#### 9e. Start working

> Pick a task from your plan and get started. With Sync set up, your Project Brain stays current for you, your agents,
> and your team in real time.

#### Follow-up (when the user asks to keep going)

| User intent | Do this |
| --- | --- |
| Brain's ready / what should I work on | `entity_lookup` project_brain → surface blockers & next steps → ask which to start |
| Start a task | Help the user pick a task, set it to in progress, and begin working. Point to plan-day and Sync if not yet introduced. |
| Set up ongoing sync | Walk through `sync/README.md` ambient install — one-time setup, then automatic updates without repeated sync invocations. |
| End the day | Suggest `/kestral:end-day-review` or `$kestral-end-day-review` for status reconciliation. |
| Add more context | Link or attach new sources, attach them to the relevant project, and rerun `trigger_brain_build`. |
| Help clear blockers | Use Kestral task tools to inspect open project work and help the user pick the next blocker. |
| Map remaining candidates | Return to extra candidate workstreams and ask one targeted question if the next split is unclear. |

## Speed and Context Rules

- Use sub-agents and parallel tool calls for independent source reads and import prep.
- Keep sub-agent outputs compact — metadata, paths, URLs, and IDs are usually enough.
- Show the manifest and proceed; the host's tool-permission prompt is the write approval gate. Ask explicit confirmation
  only for large bulk imports, 5+ projects, ambiguous scope, or hosts without per-tool prompts.

## Cancel Behavior

Before any write MCP tool has been called, `cancel` or `stop` exits cleanly. Confirm:

> Cancelled. No changes were made in Kestral.

After project creation or import writes have started, cancellation means stop future writes as soon as safely possible.
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
