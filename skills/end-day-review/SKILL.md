---
name: kestral-end-day-review
description: Use when the user asks for an end-of-day review, what got done today, what did not get done, updates to relevant Kestral project brains, or what to prioritize tomorrow; also when the user explicitly invokes /kestral:end-day-review or $kestral-end-day-review.
---

# End Day Review

Produce an evidence-backed close-out for today and a practical priority list for tomorrow. Gather current context first,
then ask before writing anything back to Kestral or local project files.

## Prerequisites

The `Kestral` MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth. Calendar access is optional,
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
2. Read `.kestral/preferences.md` by checking the current workspace folder and then parent folders. Use the first match
   as the source for durable user close-out and tomorrow-planning preferences, not as task or project state.
3. Fetch the latest Kestral daily brief with `get_daily_brief`.
4. Search Kestral tasks, projects, feedback, knowledge, and document chunks for today, especially Project Brain or named
   projects from the brief/session trail.
5. Read relevant Kestral entities directly when search results identify exact project, task, document, or project brain
   IDs.
6. Check connected MCPs/apps that are directly relevant to tomorrow prioritization, especially Calendar when the user's
   day has scheduling constraints.
7. Read local project files only when they are relevant to surfaced projects or updates, such as a matching `overview.md`
   or repo plan file.

Do not treat one source as authoritative when it conflicts with fresher live state. Prefer exact Kestral entity state
over generated summaries, and call out stale or unavailable sources.

Kestral searches to run when close-out needs verification:

- `tasks updated today <project name>`
- `urgent open tasks in <project name>`
- `blocked tasks <project name>`
- `documents updated today <project name>`
- project-level `search_content` (type: "knowledge") for current blockers, next steps, and progress

Calendar searches should use explicit local-day RFC3339 bounds for tomorrow. If calendar access is missing or empty, do
not infer a free day; state the gap.

Run independent reads in parallel whenever the host supports it: local preferences, daily brief, session trail searches,
broad Kestral searches, and tomorrow's calendar query do not need to block one another. Do not parallelize dependent
lookups; fetch exact entities only after search results identify the relevant IDs.

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
- Update `.kestral/preferences.md` when a durable preference is clear. Ask first only when the preference is ambiguous,
  appears one-off, conflicts with existing memory, or may include sensitive personal or meeting-specific content.
- Create `.kestral/` and `preferences.md` in the current workspace folder if no parent preference file exists and a
  preference write is needed. Keep the file short, in Markdown, and update existing bullets instead of appending
  duplicates.
- Do not store credentials, private personal details, or sensitive meeting content in preferences.

## Workflow

### 1. Gather today's trail

Build a compact evidence list before summarizing:

- User requests, agent actions, session transcripts, and relevant session data from today's trail.
- Kestral daily brief highlights and timestamp.
- Kestral project/task/document changes from today.
- Relevant Project Brain/project brain updates, proposed changes, blockers, and decisions.
- Calendar constraints for tomorrow if prioritization depends on available time.
- Saved close-out or prioritization preferences that materially affect the review.
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

Preference-memory updates to `.kestral/preferences.md` are separate from Kestral/local write-backs. Apply them under the
User preferences rules when durable preferences are clear, and briefly report the local file path when updated.

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
- Do not mutate Kestral, Calendar, GitHub, or local files without approval, except `.kestral/preferences.md` memory
  updates covered by the User preferences rules.
- Preserve existing `overview.md` structure when updating local project folders.
