---
name: kestral-end-day-review
description: Use when the user asks for an end-of-day review, what got done or not done today, Kestral project updates, tomorrow priorities, or invokes /kestral:end-day-review or $kestral-end-day-review.
---

# End Day Review

Produce an evidence-backed close-out for today and a practical priority list for tomorrow. Gather current context first,
then ask before writing anything back to Kestral or local project files, except `.kestral/preferences.md` memory updates
covered by the User preferences rules.

## Prerequisites

The `Kestral` MCP server must be in this session (`/mcp`). Call `whoami` first — if it fails, ask the user to
reconnect or authenticate the **Kestral** MCP server in their app's MCP settings. The agent cannot handle OAuth
directly — authenticate through your app's UI (Cowork: Customize → Connectors; Codex: Settings → MCP Servers →
Authenticate; Claude Code: `/mcp` → reconnect).
Do not call other tools until authenticated.
Calendar access is optional, but use it when tomorrow prioritization depends on schedule realism.

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

## Entrypoint

Expected invocations include:

- `/kestral:end-day-review`
- `$kestral-end-day-review`
- "What got done today and what didn't?"
- "Review today's sessions and Kestral updates, then tell me what to prioritize tomorrow."

## Data gathering order

Default order:

1. Get today's date, timezone, and relevant agent session history for the local day. Session stores are agent-specific:
   for example, Codex uses `~/.codex/sessions`, Claude Code uses `~/.claude/projects`, and other agents may use their
   own local or hosted transcript stores.
2. Read `.kestral/preferences.md` by checking the current workspace folder and then parent folders. Use the first match
   as the source for durable user close-out and tomorrow-planning preferences, not as task or project state.
3. Fetch the latest Kestral daily brief with `get_daily_brief`.
4. Search Kestral tasks, projects, feedback, knowledge, and document chunks for today, especially Project Brain or named
   projects from the brief and agent session history.
5. Read relevant Kestral entities directly when search results identify exact project, task, document, or project brain
   IDs.
6. Check remote GitHub context when available: current branch commits, open or recently updated PRs, linked PRs, and
   commit or PR references in relevant task comments.
7. Check connected MCPs/apps that are directly relevant to tomorrow prioritization, especially Calendar when the user's
   day has scheduling constraints.
8. Read local project files only when they are relevant to surfaced projects or updates, such as a matching `overview.md`
   or repo plan file.

Do not treat one source as authoritative when it conflicts with fresher live state. Prefer exact Kestral entity state
over generated summaries, and call out stale or unavailable sources.

Kestral searches to run when close-out needs verification:

- Tasks updated today in a project: use `timeFilter: "updated today"` with `projectId` (resolve the project name to an
  ID first via `entity_lookup` or `query_entities(type: "projects")`). Do not put the project name in the `query` field
  alongside `projectId` — this causes false zero-result sets from keyword matching on the project name.
- `urgent open tasks in <project name>`
- `blocked tasks <project name>`
- `documents updated today <project name>`
- For project status, blockers, next steps, and goal progress: use `entity_lookup(type: "project", id: "<projectId>")`
  or `query_entities(type: "projects", query: "<project name>")` — both return `knowledgeSummary` with blockers, next
  steps, and goal progress. Reserve `search_content(type: "knowledge", targetType: "project")` for semantic discovery
  of specific topics across all projects, not for reliable project-scoped status lookup.

Calendar searches should use explicit local-day RFC3339 bounds for tomorrow. If calendar access is missing or empty, do
not infer a free day; state the gap.

Run independent reads in parallel whenever the host supports it: local preferences, daily brief, agent session searches,
remote GitHub reads, broad Kestral searches, and tomorrow's calendar query do not need to block one another. Do not
parallelize dependent lookups; fetch exact entities only after search results identify the relevant IDs.

## User preferences

Treat `.kestral/preferences.md` as a local memory file for durable review and prioritization preferences. Find it by
walking upward from the current workspace folder and using the first match.

- Read the file before summarizing today or ranking tomorrow. If it does not exist, continue without it and mention the
  absence only when a preference write is proposed.
- Apply relevant saved preferences when recommending tomorrow priorities, such as preferred close-out format, decision
  style, focus-hour defaults, recurring projects to check, communication cadence, and work the user consistently wants
  avoided.
- Capture durable preference signals from the user's constraints, corrections, repeated edits, and stated likes/dislikes.
  Do not require the user to explicitly say "remember", "note", "save", or "prefer".
- Do not treat one-day constraints or today's mood as durable preferences. Save only stable work-style, close-out,
  prioritization, scheduling, or write-back preferences that are likely to apply across future end-day reviews.
- Update `.kestral/preferences.md` silently when a durable preference is clear. This is local memory maintenance, not a
  Kestral write-back.
- Ask before writing preferences only when the signal is ambiguous, appears one-off, conflicts with existing memory, or
  may include sensitive personal or meeting-specific content.
- Create `.kestral/` and `preferences.md` in the current workspace folder if no parent preference file exists and a
  preference write is needed. Keep the file short, in Markdown, and update existing bullets instead of appending
  duplicates.
- Do not store credentials, private personal details, or sensitive meeting content in preferences.

## Workflow

### 1. Gather today's agent history

Build a compact evidence list before summarizing:

- User requests, agent actions, session transcripts, and relevant session data from today's agent-specific session
  history.
- Kestral daily brief highlights and timestamp.
- Kestral project/task/document changes from today.
- Remote GitHub PRs, current branch commits, linked PRs, and commit references when available.
- Relevant Project Brain/project brain updates, proposed changes, blockers, and decisions.
- Calendar constraints for tomorrow if prioritization depends on available time.
- Saved close-out or prioritization preferences that materially affect the review.
- Local `overview.md` or project docs that are relevant to surfaced projects or updates.

Keep raw session review targeted. Search for today's user messages, final answers, tool calls, project names, task IDs,
PR URLs, commit SHAs, branch names, and write-back actions instead of reading every token linearly. If transcript search
or session context is unavailable, state the gap and continue from live Kestral, git, GitHub, and available local project
evidence.

### 2. Reconcile done vs not done

Separate confirmed outcomes from attempted or pending work:

- **Done:** shipped changes, created/updated tasks, documents, PRs, commits, decisions made, bugs fixed, and verified
  outcomes.
- **Not done:** explicit unfinished checklist items, blocked work, failed verification, deferred tasks, pending reviews,
  stale open questions, and work that was discussed but not executed.
- **Unclear:** items where evidence is missing or conflicting. Say what would verify them.

Use concrete project/task/document names and dates. Avoid vague claims like "made progress" unless the specific artifact
is named.

### 3. Find Project Brain updates

For each relevant project:

- Identify the Kestral project and, when available, its project brain or current generated knowledge.
- Summarize what changed today in goals, blockers, open decisions, next steps, and current status.
- Flag mismatches between live task/project state and generated Project Brain knowledge.
- Identify whether the right write-back is a task mutation, task creation, document update, comment, or `overview.md`
  maintenance.

If generated Project Brain knowledge appears stale, say that explicitly and base recommendations on live entities.

### 4. Recommend tomorrow priorities

Rank tomorrow's work by impact, urgency, unblock value, and calendar realism:

1. Must-win outcome for tomorrow.
2. Two or three next priorities.
3. Quick wins or communications that reduce risk.
4. Deferred work with a reason.

If Calendar is available, fit priorities around known meetings and preserve buffer. If Calendar is unavailable, label the
plan as task-priority-only and ask for fixed commitments if needed.

### 5. Ask before write-back

Never write back automatically. Present a specific write-back plan and wait for user approval.

Valid write-backs:

- Create Kestral tasks for newly discovered follow-ups.
- Update Kestral tasks for status, priority, due date, assignee, or description changes.
- Comment on Kestral tasks with close-out notes.
- Create or update Kestral documents with the daily review.
- Update an existing local `overview.md` in the relevant project folder.
- Create `overview.md` if the target project folder has no overview file and the folder is a local draft/project
  workspace.

For each proposed write, include target, action, and exact content summary. For task changes, include priority/status/due
date values. For document or `overview.md` edits, include the section names that will be changed.

After approval, apply only the approved writes. Return links for Kestral mutations and file paths for local edits.

Preference-memory updates to `.kestral/preferences.md` are separate from Kestral/local write-backs. Apply them silently
under the User preferences rules when durable preferences are clear; mention the local file path only if useful.

## Output shape

Use this structure unless the user asks for something else:

```markdown
## Done Today
- ...

## Not Done
- ...

## Project Brain / Project Updates
- ...

## Tomorrow Priorities
1. ...
2. ...
3. ...

## Recommended Write-Backs
- [human-readable target] [action] - [summary]

Approve these write-backs?
```

If the user already approved a specific write-back plan, replace the final question with a concise result list.

## Quality bar

- Cite evidence with Kestral links, local file paths, task slugs, document titles, PR URLs, or session filenames when
  possible.
- Keep raw Kestral IDs internal to search and lookup steps. In final summaries and write-back plans, use `slug - title` for tasks and readable names/titles for projects, documents, feedback, customers, statuses, tags, and members.
- Include data gaps instead of hiding them.
- Do not mutate Kestral, Calendar, GitHub, or local files without approval, except `.kestral/preferences.md` memory
  updates covered by the User preferences rules.
- Preserve existing `overview.md` structure when updating local project folders.
