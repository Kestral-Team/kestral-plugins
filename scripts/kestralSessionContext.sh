#!/usr/bin/env bash
# Injects a session-start reminder to load Kestral sync instructions.
# Fail-open — always exit 0.
#
# Usage: kestralSessionContext.sh <cursor|claude|codex>

set -euo pipefail

host="${1:-cursor}"
cat >/dev/null || true

if ! command -v git >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

branch=$(git branch --show-current 2>/dev/null || true)
if [[ -z "$branch" ]]; then
  echo '{}'
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

ctx="REQUIRED FIRST ACTION: Call execute_operation on the Kestral MCP server (registered as \"Kestral\") with operationId=\"sync_session_workflow\", params={ intent: \"session_start\" }, explanation=\"Loading sync trigger instructions for session on branch ${branch}\". Do this before answering the user's question. The response configures sync triggers for the rest of the session."

if [[ "$host" == "claude" || "$host" == "codex" ]]; then
  jq -n --arg ctx "$ctx" \
    '{ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $ctx } }'
else
  jq -n --arg ctx "$ctx" '{ additional_context: $ctx }'
fi
exit 0
