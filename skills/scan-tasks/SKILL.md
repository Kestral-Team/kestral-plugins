---
name: kestral-scan-tasks
description: Use when kestral-setup or the user asks to scan task systems such as Linear, Jira, GitHub Issues, Asana, ClickUp, or Shortcut for importable work.
---

# Scan Tasks

Detect available task-shaped MCP tools, list open + recently completed tasks, and translate them to the
Kestral import schema. Returns a result the caller (`kestral-setup/SKILL.md`) uses to populate the manifest.

## Known patterns

Match MCP tool names against these baselines first (case-insensitive):

| Tool name pattern | Source label |
| --- | --- |
| `linear_list_issues`, `linear_search_issues`, `linear_get_issues` | `linear` |
| `jira_search`, `jira_list_issues`, `jira_get_issues` | `jira` |
| `github_list_issues`, `github_search_issues` | `github` |
| `asana_get_tasks`, `asana_list_tasks`, `asana_search_tasks` | `asana` |
| `clickup_get_tasks`, `clickup_list_tasks` | `clickup` |
| `shortcut_list_stories`, `shortcut_search_stories` | `shortcut` |

## Heuristic fallback

If no known-pattern tool is found, scan all available MCP tool names and descriptions for keywords:
`issue`, `task`, `ticket`, `story`, `work item`, `backlog`. A match counts as a potential task MCP.

Use judgment: a tool named `create_issue` (write-only) or `get_issue_comments` (metadata) is NOT a list
tool. Only tools that **return a list of task-like objects** qualify.

## Detection output

If **zero** task MCPs are detected, return immediately:

```json
{ "tasks": [], "workstreamSignals": [], "moreMatchingCounts": [], "warnings": [], "sources": [] }
```

Do NOT prompt the user to install a task MCP. Silent empty result is correct behavior.

## Listing tasks

For each detected task MCP, call the list/search tool with parameters to retrieve:

- **Open tasks** (status: open, in-progress, todo, or equivalent)
- **Recently completed tasks** (completed in the last 30 days)

Use the tool's available filters. If the tool doesn't support date filtering for completed tasks, fetch
recently updated completed tasks with bounded metadata paging, newest-first. Stop when you reach tasks completed before
the 30-day cutoff or 200 candidates for that source, whichever comes first.

Prefer lightweight metadata first: title, source ID, project/epic/milestone, labels, status, priority, assignee,
created/updated/completed dates, and URL. Do not fetch or retain full descriptions for every task during taxonomy
inference. Fetch descriptions only for selected representative tasks or tasks the user asks to import.

**Discovery preview bound:** Fetch up to **200 task metadata records** per source for initial workstream taxonomy and
manifest preview. If the source returns more, take the first 200 most recent by creation, update, or completion date.
This is not a product-level import cap.

After the user approves projects, if they ask to import more matching tasks or all matching tasks, page through every
matching task in batches using metadata and source IDs where possible. Fetch descriptions only for tasks actually being
imported. Do not impose a Kestral setup cap on import volume; only technical, API, or batch-size limits apply.

## Translation

Return readable task import data. External task IDs from Linear, Jira, GitHub, or other sources are provenance/debug
details only and should not appear in the setup manifest unless the user explicitly asks for source IDs.

For each task from each source, translate to Kestral schema:

```typescript
interface ImportTask {
  title: string;        // required — the task title/summary
  description?: string; // body/description text only when fetched for selected imports
  source: string;       // lowercase source label from detection (e.g. 'linear', 'jira')
  priority?: number;    // 0=none, 1=urgent, 2=high, 3=medium, 4=low — map from source's priority system
  dueDate?: string;     // YYYY-MM-DD format if available
}
```

Do not load all full task descriptions into context by default. Keep enough metadata to infer workstreams, then fetch
task descriptions only for selected representative tasks or approved imports.

### Priority mapping

| Source system | Urgent | High | Medium | Low | None/unset |
| --- | --- | --- | --- | --- | --- |
| Linear | 1 (urgent) | 2 (high) | 3 (medium) | 4 (low) | 0 (no priority) |
| Jira | Highest→1 | High→2 | Medium→3 | Low→4 | Lowest→4, unset→0 |
| GitHub | — | — | — | — | 0 (no priority system) |
| Asana | — | High→2 | Medium→3 | Low→4 | 0 |

For sources not in this table, map to `0` (none) unless the source clearly provides priority levels.

### Translation failures

If a single task cannot be translated (missing title, unexpected structure), add a warning and skip it:

```json
{ "index": 3, "source": "linear", "reason": "Task has no title field" }
```

Translation failures are **warnings**, not errors. Never abort the batch for a single malformed task.

## Return value

```json
{
  "tasks": [
    { "title": "Fix login bug", "source": "linear", "priority": 2 }
  ],
  "workstreamSignals": [
    {
      "label": "Authentication migration",
      "source": "linear",
      "evidence": ["Linear project: Auth", "12 open tasks", "recent updates this week"],
      "confidence": "high"
    }
  ],
  "moreMatchingCounts": [
    { "label": "Authentication migration", "source": "linear", "count": 43 }
  ],
  "warnings": [
    { "index": 3, "source": "linear", "reason": "Task has no title field" }
  ],
  "sources": ["linear"]
}
```

The caller uses `tasks` for selected manifest tasks, `workstreamSignals` and `moreMatchingCounts` for taxonomy and
coverage, `sources` for labels, and `warnings` for the final report.
