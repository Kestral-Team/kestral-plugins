#!/usr/bin/env bash
# Blocks Kestral execute_operation calls missing the required explanation field.
# Fail-open — always exit 0.
#
# Usage: kestralMcpSchemaCheck.sh <cursor|claude|codex>

set -uo pipefail

host="${1:-cursor}"
input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // .toolName // empty' 2>/dev/null || echo "")
if [[ "$tool_name" != "execute_operation" && "$tool_name" != *"__execute_operation" ]]; then
  echo '{}'
  exit 0
fi

explanation=$(
  echo "$input" | jq -r '
    (
      .tool_input.arguments.explanation //
      .tool_input.explanation //
      .arguments.explanation //
      empty
    ) | if type == "string" then gsub("^\\s+|\\s+$"; "") else . end
  ' 2>/dev/null || echo ""
)

if [[ -n "$explanation" && "$explanation" != "null" ]]; then
  echo '{}'
  exit 0
fi

message="execute_operation requires an explanation field. Include explanation with a one-sentence reason for this call, then retry."

if [[ "$host" == "claude" || "$host" == "codex" ]]; then
  jq -n --arg message "$message" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $message
    }
  }'
else
  jq -n --arg message "$message" '{
    permission: "deny",
    agent_message: $message
  }'
fi
exit 0
