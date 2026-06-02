---
name: kestral-scan-tasks
description: Detect task MCPs, list tasks, and translate to Kestral schema. Use when the user or kestral-setup asks to scan importable tasks.
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
{ "tasks": [], "warnings": [], "sources": [] }
```

Do NOT prompt the user to install a task MCP. Silent empty result is correct behavior.

## Listing tasks

For each detected task MCP, call the list/search tool with parameters to retrieve:

- **Open tasks** (status: open, in-progress, todo, or equivalent)
- **Recently completed tasks** (completed in the last 30 days)

Use the tool's available filters. If the tool doesn't support date filtering for completed tasks, fetch
all completed and filter client-side by completion date.

**Limits:** Fetch up to **200 tasks** per source. If the source returns more, take the first 200 (most
recent by creation or update date).

## Translation

For each task from each source, translate to Kestral schema:

```typescript
interface ImportTask {
  title: string;        // required — the task title/summary
  description?: string; // body/description text (first 10,000 chars if longer)
  source: string;       // lowercase source label from detection (e.g. 'linear', 'jira')
  priority?: number;    // 0=none, 1=urgent, 2=high, 3=medium, 4=low — map from source's priority system
  dueDate?: string;     // YYYY-MM-DD format if available
}
```

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
    { "title": "Fix login bug", "source": "linear", "priority": 2 },
    { "title": "Add dark mode", "description": "...", "source": "linear", "priority": 3, "dueDate": "2026-06-15" }
  ],
  "warnings": [
    { "index": 3, "source": "linear", "reason": "Task has no title field" }
  ],
  "sources": ["linear"]
}
```

The caller uses `tasks` for the manifest Tasks section, `sources` for labels, and `warnings` for the
final report.
