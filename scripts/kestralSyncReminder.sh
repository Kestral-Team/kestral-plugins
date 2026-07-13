#!/usr/bin/env bash
# Nudges the agent to sync with Kestral after push/submit/PR create.
# Fail-open — always exit 0.
#
# Usage: kestralSyncReminder.sh <cursor|claude|codex>

set -euo pipefail

host="${1:-cursor}"
input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
  echo '{}'
  exit 0
fi

# Match git push, Graphite submit, or gh pr create — not read-only git commands.
if [[ ! "$command" =~ (^|[;&|[:space:]])(git[[:space:]]+push|gt[[:space:]]+(s|submit|ss)([[:space:]]|$)|gh[[:space:]]+pr[[:space:]]+create) ]]; then
  echo '{}'
  exit 0
fi

ctx='A push/submit/PR operation just completed. Sync to Kestral NOW — this is a multi-step process:

Step 1: Call execute_operation on the Kestral MCP server (registered as "Kestral") with
  operationId="sync_session_workflow", params={ intent: "update_or_create" },
  explanation="<describe what was pushed>".

Step 2: The response contains sync INSTRUCTIONS and context (active tasks, projects).
  You MUST follow the "Full Sync" workflow in those instructions. At minimum:
  - Look up a task via find_task_by_branch for the current branch
  - If no task exists, create one (see "Unlinked Branch — Auto-Create")
  - Post a progress comment
  - Link the branch/PR if applicable

Do NOT stop after Step 1. Receiving instructions is not the same as syncing.'

if [[ "$host" == "claude" || "$host" == "codex" ]]; then
  jq -n --arg ctx "$ctx" \
    '{ hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $ctx } }'
else
  jq -n --arg ctx "$ctx" '{ additional_context: $ctx }'
fi
exit 0
