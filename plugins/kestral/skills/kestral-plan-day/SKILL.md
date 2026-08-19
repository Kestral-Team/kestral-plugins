---
name: kestral-plan-day
description: Use when the user asks to plan today, start the workday, prioritize from a Kestral brief, use a morning or daily brief, or invokes /kestral:plan-day or $kestral-plan-day.
---

# Plan Day

Create a daily operating plan from Kestral's current daily brief, relevant project/task state, and the user's calendar
for today plus the next two business days. The plan should make brief context actionable: what changed, what needs
attention, what fits today, and what should be deferred.

## Prerequisites

The `Kestral` MCP server must be in this session (`/mcp`). Authentication is handled by the MCP connection — proceed
directly with data-fetching calls. If any call returns auth failure (401, unauthorized, or `Not authenticated`), ask the
user to reconnect or authenticate the **Kestral** MCP server through their app's UI (Cowork: Customize → Connectors;
Codex: authenticate then start a new thread using `/new` — CLI: `codex mcp login Kestral`; app: Plugins → Kestral → MCP servers
gear; Claude Code: `/mcp` → reconnect). A calendar MCP/app connector should also
be available for best results. If calendar access is missing, the behavior depends on whether this is the user's first
plan-day after a kestral-setup in the same session:

**First plan-day after setup (same session):** The user just finished onboarding and is trying plan-day for the first
time. Guide them toward connecting a calendar — this is the best moment to set it up:

> Plan-day works best with your calendar — it avoids scheduling over meetings and shows free blocks for focus time.
>
> **To connect a calendar** (e.g. Google Calendar): install the calendar plugin or connector in your app's settings
> (Cowork: Customize → Connectors; Claude Code: `/mcp`; Cursor: Settings → MCP Servers).
>
> You can skip this and plan from tasks and your brief alone — calendar is optional.

If they connect it, proceed. If they skip, do not repeat the guidance.

**All other invocations** (standalone, subsequent runs, new sessions): Note briefly and move on — do not push connector
setup:

> No calendar connected — planning from tasks and your brief. Tell me any fixed commitments so I don't schedule over
> them.

In both cases, ask for fixed commitments before finalizing the plan when calendar is unavailable.

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

## Entrypoint

Expected invocations include:

- `/kestral:plan-day`
- `$kestral-plan-day`
- "Turn my Kestral morning brief into a plan for today."
- "Look at my brief and calendar and tell me what to focus on."

## Data gathering order

Default order:

1. Fetch bundled planning context with `execute_operation("get_daily_planning_context", { timezone })`. This returns
   `daily_brief`, `my_active_tasks`, `my_overdue_tasks`, `my_blocked_tasks`, and `load_status` in one call. Pass the
   user's local IANA timezone when known (e.g. from stated locale, calendar connector, or ask once if unclear). Check
   `load_status` before the Morning Readout: if a section is `false`, treat that slice as missing and use the fallbacks
   in step 4 (`get_daily_brief` for brief-only failure; targeted task ops for failed task sections).
2. Read `.kestral/preferences.md` by checking the current workspace folder and then parent folders. Use the first match
   as the source for durable user planning preferences, not as a task or project source of truth.
3. Read calendar events for today and the next two business days using the available calendar MCP/app connector. Include
   event titles, times, attendees when visible, and free/busy pressure. Do not assume empty calendar access means no
   meetings; state access gaps.
4. If the bundled response is insufficient (e.g. need project-scoped searches, stale-task sweep, or cross-team work), or
   `load_status` marks a section failed, run targeted task searches:
   - Prefer `my_overdue_tasks` from the bundle for overdue work before extra searches.
   - `execute_operation("list_stale_tasks", { staleDays: 7, assigneeFilter: "me" })` — active tasks not updated in the
     last 7 days (stale/forgotten commitments).
   - `execute_operation("search_tasks_by_time", { timeFilter: "due in the next two business days", assigneeFilter: "me", sortBy: "dueDate" })`
     — tasks due today through the next two business days (weekends skipped; anchored to caller local time via MCP
     context).
   - For blocked work, prefer `execute_operation("list_blocked_tasks", { assigneeFilter: "me" })` over semantic
     `search_tasks` with query "blocked tasks".
5. Search or fetch Kestral projects only when the brief or task search names a project without enough detail to plan
   around it.
6. Use deeper Kestral research only when cross-project state is ambiguous and the extra latency is justified.

Task search results include slug, assignee name, status, priority, due date, blocker counts, up to five
`recentComments`, `doabilityState`, `doabilityReason`, and URL. Use these fields directly for the Morning Readout —
do not call `entity_lookup` to re-verify search results. Reserve `entity_lookup` for tasks referenced by slug/URL in the
brief that were not returned by search, or when you need older comment history.

Treat priority as importance, not executability. A high priority or near due date never overrides
`doabilityState: waiting` or `doabilityState: blocked`. Use the shared doability result whenever it is present:

- `doable` — eligible for focus work **only after** you read `recentComments`. If comments show an external wait, treat
  the task as waiting even when `doabilityState` is still `doable`.
- `waiting` or `blocked` — never schedule execution of the task. Put it in a separate **Blocked/Waiting** lane and, when
  useful, schedule only a communication or unblock follow-up such as contacting a vendor.
- `unknown` — do not present the task as confidently executable. Verify it when it is central to the day; otherwise
  label the uncertainty and keep it out of the must-win focus.

Structured doability covers formal blocker relationships and holding/waiting statuses only (Project Brain blockers are
a Daily Brief hard gate, not Plan Day). For Plan Day, read the last few task comments on every candidate before
scheduling execution. The planning context also uses project involvement/activity, assignment, status, priority, due
date, and staleness to decide relevance and urgency. These signals rank what deserves attention; they do not rewrite
stored priorities or due dates.

Start data gathering immediately. Run independent reads in parallel whenever the host supports it: bundled planning
context, local preferences, and calendar do not need to block one another. Do not parallelize dependent checks; fetch
exact tasks or projects only after the brief or search results identify what needs verification.

Calendar event searches should use explicit local-day RFC3339 bounds from start-of-day today through end-of-day of the
second business day after today, skipping weekends. If today is a weekend, still include today plus the next two
weekdays. If only free/busy access is available, use busy windows but state that event details are unavailable. Do not
create or update calendar events unless the user explicitly asks.

## User preferences

Treat `.kestral/preferences.md` as a local memory file for durable day-planning preferences. Find it by walking upward
from the current workspace folder and using the first match.

- Read the file before drafting the plan; if it does not exist, continue without it and mention the absence only when a
  preference write is proposed.
- Apply relevant saved preferences when drafting the plan, such as preferred focus hours, meeting buffers, planning
  style, recurring must-check projects, communication cadence, and work the user consistently wants avoided.
- Capture durable preference signals from the user's constraints, corrections, repeated edits, and stated
  likes/dislikes. Do not require the user to explicitly say "remember", "note", "save", or "prefer".
- Do not treat one-day constraints as durable preferences. Save only stable work-style, planning, scheduling, or
  write-back preferences that are likely to apply across future plan-day runs.
- Update `.kestral/preferences.md` silently when a durable preference is clear. This is local memory maintenance, not a
  Kestral write-back.
- Ask before writing preferences only when the signal is ambiguous, appears one-off, conflicts with existing memory, or
  may include sensitive personal or meeting-specific content.
- If the user explicitly asks to update preferences, update `.kestral/preferences.md` in the same turn before
  finalizing. Preference-memory writes are local workspace memory maintenance, not Kestral write-backs; do not skip them
  because the user declined or redirected Kestral write-back for the day plan.
- Create `.kestral/` and `preferences.md` in the current workspace folder if no parent preference file exists and a
  preference write is needed. Keep the file short, in Markdown, and update existing bullets instead of appending
  duplicates.
- Do not store credentials, private personal details, or sensitive meeting content in preferences.

## Workflow

Use the same task rendering posture throughout: verify only decision-relevant tasks, keep raw IDs internal, and name
tasks as `slug - title` when a slug exists. For projects, documents, and other entities, use readable names/titles plus
URLs when useful.

### 0. Gather first

Do not ask for constraints before data gathering. Start by loading bundled planning context, local preferences, and
calendar; run targeted task searches only when the bundle is incomplete or `load_status` reports a failed section. Run
independent reads in parallel whenever the host supports it.

This keeps the first real user question visible in the conversation instead of relying on transient progress or status
messages for input that changes the plan.

### 1. Brief the brief

Summarize the most important inputs before asking the user to plan:

- Major project updates since the last brief, only when they affect today's choices.
- Critical blockers, pending Project Brain changes, and decisions needing user attention.
- The top 3-5 urgent, overdue, stale, or due-soon **doable** tasks; do not list every candidate task.
- A short Blocked/Waiting callout for important non-doable tasks, clearly separated from do-now recommendations.
- Calendar constraints: today's real meeting pressure, best focus windows, and only notable events in the next two
  business days.
- Saved planning preferences that materially affect today's plan.
- Data-quality caveats, especially missing or stale brief/calendar data.

Keep this short enough to scan. Default to a terse operating picture: critical blockers, today's usable windows, and the
top tasks that could change the plan.

Resolve contradictions selectively. Verify live state for tasks or projects only when they are blockers,
launch-critical, assigned to the user, due soon, or central to the proposed must-win. Do not deep-inspect every
referenced task just because it appears in the brief. Do not call `entity_lookup` on tasks already returned by
`get_daily_planning_context` or `search_tasks` — those results already include slug, assignee, status, and URL. When
generated Project Brain knowledge conflicts with live task/project fields, label the generated knowledge as stale and
prefer the live record for planning.

Before naming a must-win or placing work in a focus block, check its `doabilityState`. Keep `waiting`, `blocked`, and
unverified `unknown` tasks out of do-now work even when they are high priority, overdue, or due today.

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
- A separate **Blocked/Waiting** lane for non-doable tasks, including the reason and an optional communication or
  unblock follow-up. Never schedule execution of the blocked task itself.
- Deferred/non-priority work with a short reason.

Make the plan realistic. Do not fill every free minute. Reserve buffer when the calendar is fragmented or blocker-heavy.
Rank focus work by urgency only after applying the doability gate.

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

- Check `load_status.daily_brief` from the bundled response first.
- Say what is missing and the timestamp if available.
- Fall back to `execute_operation("get_daily_brief", { timezone })`, overdue/stale task searches from step 4, plus
  calendar events.
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

## Blocked/Waiting

- [task] — [waiting/blocked reason]; [optional communication or unblock follow-up]

## Defer

- ...

## Write-Back

[ask whether to save/link the final plan]
```
