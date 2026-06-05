---
name: kestral-end-day-review
description: Use when the user asks for an end-of-day review, what got done today, what did not get done, updates to relevant Kestral project brains, or what to prioritize tomorrow; also when the user explicitly invokes /kestral:end-day-review or $kestral-end-day-review.
---

# End Day Review

Produce an evidence-backed close-out for today and a practical priority list for tomorrow. Gather current context first,
then ask before writing anything back to Kestral or local project files.

## Prerequisites

The `kestral` MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth. Calendar access is optional,
but use it when tomorrow prioritization depends on schedule realism.

## Entrypoint

Expected invocations include:

- `/kestral:end-day-review`
- `$kestral-end-day-review`
- "What got done today and what didn't?"
- "Review today's sessions and Kestral updates, then tell me what to prioritize tomorrow."

## Data gathering order

Default order:

1. Get today's date, timezone, relevant local agent session trail, session transcripts, and session data when available.
2. Fetch the latest Kestral daily brief with `get_daily_brief`.
3. Search Kestral tasks, projects, feedback, knowledge, and document chunks for today, especially Project Brain or named
   projects from the brief/session trail.
4. Read relevant Kestral entities directly when search results identify exact project, task, document, or project brain
   IDs.
5. Check connected MCPs/apps that are directly relevant to tomorrow prioritization, especially Calendar when the user's
   day has scheduling constraints.
6. Read local project files only when they are relevant to surfaced projects or updates, such as a matching `overview.md`
   or repo plan file.

Do not treat one source as authoritative when it conflicts with fresher live state. Prefer exact Kestral entity state
over generated summaries, and call out stale or unavailable sources.

Kestral searches to run when close-out needs verification:

- `tasks updated today <project name>`
- `urgent open tasks in <project name>`
- `blocked tasks <project name>`
- `documents updated today <project name>`
- project-level `search_knowledge` for current blockers, next steps, and progress

Calendar searches should use explicit local-day RFC3339 bounds for tomorrow. If calendar access is missing or empty, do
not infer a free day; state the gap.

## Workflow

### 1. Gather today's trail

Build a compact evidence list before summarizing:

- User requests, agent actions, session transcripts, and relevant session data from today's trail.
- Kestral daily brief highlights and timestamp.
- Kestral project/task/document changes from today.
- Relevant Project Brain/project brain updates, proposed changes, blockers, and decisions.
- Calendar constraints for tomorrow if prioritization depends on available time.
- Local `overview.md` or project docs that are relevant to surfaced projects or updates.

Keep raw session review targeted. Search for today's user messages, final answers, tool calls, project names, task IDs,
PR URLs, and write-back actions instead of reading every token linearly.

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
- [target] [action] - [summary]

Approve these write-backs?
```

If the user already approved a specific write-back plan, replace the final question with a concise result list.

## Quality bar

- Cite evidence with Kestral links, local file paths, task slugs, document titles, PR URLs, or session filenames when
  possible.
- Include data gaps instead of hiding them.
- Do not mutate Kestral, Calendar, GitHub, or local files without approval.
- Preserve existing `overview.md` structure when updating local project folders.
