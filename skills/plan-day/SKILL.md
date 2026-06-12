---
name: kestral-plan-day
description: Use when the user asks to plan today, start the workday, prioritize from a Kestral brief, use a morning or daily brief, or invokes /kestral:plan-day or $kestral-plan-day.
---

# Plan Day

Create a daily operating plan from Kestral's current daily brief, relevant project/task state, and the user's calendar for
today plus the next two business days. The plan should make brief context actionable: what changed, what needs
attention, what fits today, and what should be deferred.

## Prerequisites

The `Kestral` MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth. A calendar MCP/app connector
should also be available for best results; if calendar access is missing, ask the user for fixed commitments before
finalizing the plan.

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

- `/kestral:plan-day`
- `$kestral-plan-day`
- "Turn my Kestral morning brief into a plan for today."
- "Look at my brief and calendar and tell me what to focus on."

## Data gathering order

Default order:

1. Fetch the Kestral daily brief with `get_daily_brief`.
2. Read `.kestral/preferences.md` by checking the current workspace folder and then parent folders. Use the first match
   as the source for durable user planning preferences, not as a task or project source of truth.
3. Read calendar events for today and the next two business days using the available calendar MCP/app connector. Include
   event titles, times, attendees when visible, and free/busy pressure. Do not assume empty calendar access means no
   meetings; state access gaps.
4. Search Kestral tasks for urgent, overdue, blocked, stale, due-today, and due-soon work.
5. Search or fetch Kestral projects only when the brief or task search names a project without enough detail to plan
   around it.
6. Use deeper Kestral research only when cross-project state is ambiguous and the extra latency is justified.

Start data gathering immediately. Run independent reads in parallel whenever the host supports it: daily brief, local
preferences, calendar, broad task searches, and profile/member lookup do not need to block one another. Do not parallelize
dependent checks; fetch exact tasks or projects only after the brief or search results identify what needs verification.

Kestral task searches to run when planning needs verification:

- `urgent tasks due today or overdue`
- `blocked tasks`
- `stale commitments or tasks not updated recently`
- `tasks due today or in the next two business days`

Calendar event searches should use explicit local-day RFC3339 bounds from start-of-day today through end-of-day of the
second business day after today, skipping weekends. If today is a weekend, still include today plus the next two weekdays.
If only free/busy access is available, use busy windows but state that event details are unavailable. Do not create or
update calendar events unless the user explicitly asks.

## User preferences

Treat `.kestral/preferences.md` as a local memory file for durable day-planning preferences. Find it by walking upward
from the current workspace folder and using the first match.

- Read the file before drafting the plan; if it does not exist, continue without it and mention the absence only when a
  preference write is proposed.
- Apply relevant saved preferences when drafting the plan, such as preferred focus hours, meeting buffers, planning
  style, recurring must-check projects, communication cadence, and work the user consistently wants avoided.
- Capture durable preference signals from the user's constraints, corrections, repeated edits, and stated likes/dislikes.
  Do not require the user to explicitly say "remember", "note", "save", or "prefer".
- Do not treat one-day constraints as durable preferences. Save only stable work-style, planning, scheduling, or
  write-back preferences that are likely to apply across future plan-day runs.
- Update `.kestral/preferences.md` silently when a durable preference is clear. This is local memory maintenance, not a
  Kestral write-back.
- Ask before writing preferences only when the signal is ambiguous, appears one-off, conflicts with existing memory, or
  may include sensitive personal or meeting-specific content.
- If the user explicitly asks to update preferences, update `.kestral/preferences.md` in the same turn before finalizing.
  Preference-memory writes are local workspace memory maintenance, not Kestral write-backs; do not skip them because the
  user declined or redirected Kestral write-back for the day plan.
- Create `.kestral/` and `preferences.md` in the current workspace folder if no parent preference file exists and a
  preference write is needed. Keep the file short, in Markdown, and update existing bullets instead of appending
  duplicates.
- Do not store credentials, private personal details, or sensitive meeting content in preferences.

## Workflow

Use the same task rendering posture throughout: verify only decision-relevant tasks, keep raw IDs internal, and name tasks as `slug - title` when a slug exists. For projects, documents, and other entities, use readable names/titles plus URLs when useful.

### 0. Gather first

Do not ask for constraints before data gathering. Start by loading the Kestral brief, local preferences, calendar, and
broad task searches. Run independent reads in parallel whenever the host supports it.

This keeps the first real user question visible in the conversation instead of relying on transient progress or status
messages for input that changes the plan.

### 1. Brief the brief

Summarize the most important inputs before asking the user to plan:

- Major project updates since the last brief, only when they affect today's choices.
- Critical blockers, pending Project Brain changes, and decisions needing user attention.
- The top 3-5 urgent, overdue, stale, or due-soon tasks; do not list every candidate task.
- Calendar constraints: today's real meeting pressure, best focus windows, and only notable events in the next two
  business days.
- Saved planning preferences that materially affect today's plan.
- Data-quality caveats, especially missing or stale brief/calendar data.

Keep this short enough to scan. Default to a terse operating picture: critical blockers, today's usable windows, and the
top tasks that could change the plan.

Resolve contradictions selectively. Verify live state for tasks or projects only when they are blockers, launch-critical,
assigned to the user, due soon, or central to the proposed must-win. Do not deep-inspect every referenced task just
because it appears in the brief. When generated Project Brain knowledge conflicts with live task/project fields, label the
generated knowledge as stale and prefer the live record for planning.

### 2. Ask constraints before planning

After the Morning Readout, ask for user constraints before drafting the final plan. Prefer one compact question with
concrete fields:

- Available focus time today.
- Meeting load or calendar constraints that MCP data may not reveal.
- Energy level.
- Hard deadlines.
- Must-win outcome for the day.
- Any work that should be explicitly avoided or deferred.

If the user already provided these constraints, do not ask again; restate the assumptions and continue.

If the user has not provided constraints, stop after the readout and this question unless they explicitly ask for a
best-effort plan.

If the conversation reveals a new durable planning preference, update `.kestral/preferences.md` as local memory when the
preference is clear. Do not include this in the Kestral write-back approval plan. Ask before writing only when the
preference is ambiguous, one-off, sensitive, or conflicts with existing memory.

### 3. Draft the day plan

Produce a ranked plan with:

- One must-win outcome.
- Focus blocks that fit around known calendar events.
- Quick wins that reduce risk or clear stale commitments.
- Decision or communication checkpoints.
- Prep/follow-up blocks for meetings today or in the next two business days.
- Deferred/non-priority work with a short reason.

Make the plan realistic. Do not fill every free minute. Reserve buffer when the calendar is fragmented or blocker-heavy.

### 4. Adjust conversationally

Invite edits before treating the plan as final. Useful adjustment prompts:

- "Want this optimized for deep work, shipping risk, or communication cleanup?"
- "Should I make this more aggressive or more conservative?"
- "Anything on the calendar that needs prep I cannot infer?"

When the user revises constraints, update the ranking and explain only the meaningful changes.

### 5. Optional write-back

Do not write the plan back automatically. Ask before writing.

Default write-back target:

- Create a Kestral document titled `Daily Plan - YYYY-MM-DD` when the plan spans multiple projects.

Other valid targets:

- Attach the document to a project when the user selects one primary project.
- Comment on a specific Kestral task when the day plan is primarily a task execution plan.
- Update task priority/due dates only when the user explicitly asks for those mutations.
- `.kestral/preferences.md` memory updates are not Kestral write-backs and do not require the write-back approval table.

When updating `.kestral/preferences.md`, mention the local file path only if useful. After Kestral writes, return the
Kestral link.

## Missing or stale data

If the daily brief is missing, stale, or obviously incomplete:

- Say what is missing and the timestamp if available.
- Fall back to urgent/overdue/stale task searches plus calendar events.
- Ask whether the user wants a best-effort plan or wants to refresh/generate the brief first.

If calendar access is missing:

- Continue with Kestral-only planning only after noting the gap.
- Ask the user for meetings or fixed commitments before finalizing.

If Kestral task/project search is unavailable:

- Plan from the brief and calendar, but label task urgency as unverified.

## Output shape

Use this structure unless the user asks for something else:

```markdown
## Morning Readout
[brief, blockers, decisions, urgent/stale work, calendar pressure]

## Constraints
[known constraints and assumptions]

## Plan
1. [time block or priority] - [outcome]
2. ...

## Quick Wins
- ...

## Defer
- ...

## Write-Back
[ask whether to save/link the final plan]
```
