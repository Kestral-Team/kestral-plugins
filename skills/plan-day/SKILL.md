---
name: kestral-plan-day
description: Turn Kestral daily or morning brief context plus the user's calendar into a realistic day plan. Use when the user asks to plan the day, start the workday, use a morning/daily brief, prioritize today, turn Kestral updates into focus blocks, or explicitly invokes /kestral:plan-day or $kestral-plan-day.
---

# Plan Day

Create a daily operating plan from Kestral's current daily brief, relevant project/task state, and the user's calendar for
today plus the next two days. The plan should make brief context actionable: what changed, what needs attention, what
fits today, and what should be deferred.

## Prerequisites

The `kestral` MCP server must show as **connected** (`/mcp`). Auth is automatic via OAuth. A calendar MCP/app connector
should also be available for best results; if calendar access is missing, ask the user for fixed commitments before
finalizing the plan.

## Entrypoint

Expected invocations include:

- `/kestral:plan-day`
- `$kestral-plan-day`
- "Turn my Kestral morning brief into a plan for today."
- "Look at my brief and calendar and tell me what to focus on."

## Data gathering order

Default order:

1. Fetch the Kestral daily brief with `get_daily_brief`.
2. Read calendar events for today and the next two days using the available calendar MCP/app connector. Include event
   titles, times, attendees when visible, and free/busy pressure. Do not assume empty calendar access means no meetings;
   state access gaps.
3. Search Kestral tasks for urgent, overdue, blocked, stale, due-today, and due-soon work.
4. Search or fetch Kestral projects only when the brief or task search names a project without enough detail to plan
   around it.
5. Use deeper Kestral research only when cross-project state is ambiguous and the extra latency is justified.

Kestral task searches to run when planning needs verification:

- `urgent tasks due today or overdue`
- `blocked tasks`
- `stale commitments or tasks not updated recently`
- `tasks due in the next three days`

Calendar event searches should use explicit local-day RFC3339 bounds from start-of-day today through end-of-day two days
after today. If only free/busy access is available, use busy windows but state that event details are unavailable. Do not
create or update calendar events unless the user explicitly asks.

## Workflow

### 1. Brief the brief

Summarize the most important inputs before asking the user to plan:

- Major project updates since the last brief.
- Active blockers, pending Project Brain changes, and decisions needing user attention.
- Urgent tasks, overdue work, stale commitments, and due-soon deadlines.
- Calendar constraints: meetings today, fragmented time, prep/follow-up needs, and notable events in the next two days.
- Data-quality caveats, especially missing or stale brief/calendar data.

Keep this short enough to scan. The user should see the operating picture, not a rewritten daily brief.

### 2. Ask constraints before planning

Ask for user constraints before finalizing. Prefer one compact question with concrete fields:

- Available focus time today.
- Meeting load or calendar constraints that MCP data may not reveal.
- Energy level.
- Hard deadlines.
- Must-win outcome for the day.
- Any work that should be explicitly avoided or deferred.

If the user already provided these constraints, do not ask again; restate the assumptions and continue.

### 3. Draft the day plan

Produce a ranked plan with:

- One must-win outcome.
- Focus blocks that fit around known calendar events.
- Quick wins that reduce risk or clear stale commitments.
- Decision or communication checkpoints.
- Prep/follow-up blocks for meetings today or tomorrow.
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

After writing, return the Kestral link.

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
