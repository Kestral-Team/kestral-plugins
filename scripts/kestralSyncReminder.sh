#!/usr/bin/env bash
# Nudges the agent to sync with Kestral after push/submit/PR create via sync_after_push.
# Only fires when the repo is opted in (home hook-repos.json linked, or legacy markers).
# Fail-open — always exit 0.
#
# Usage: kestralSyncReminder.sh <cursor|claude|codex>

set -euo pipefail

host="${1:-cursor}"
input=$(cat)

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_kestralProjectLinked.sh
source "${script_dir}/_kestralProjectLinked.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$command" ]]; then
  echo '{}'
  exit 0
fi

# Match git push, Graphite submit, or gh pr create — not read-only git commands.
if [[ ! "$command" =~ (^|[;&|[:space:]])(git[[:space:]]+push|gt[[:space:]]+(s|submit|ss)([[:space:]]|$)|gh[[:space:]]+pr[[:space:]]+create) ]]; then
  echo '{}'
  exit 0
fi

repo_root=""
if [[ "$host" == "cursor" ]]; then
  repo_root="$(kestral_resolve_cursor_project_root "$input")"
  if [[ -z "$repo_root" ]]; then
    echo '{}'
    exit 0
  fi
fi

if ! kestral_project_linked "$repo_root"; then
  echo '{}'
  exit 0
fi

branch=$(kestral_git "$repo_root" branch --show-current 2>/dev/null || true)

if [[ -z "$branch" ]]; then
  branch='<current-branch>'
fi

ctx="A push/submit/PR just completed. Sync with one call — do not run Full Sync / sync_session_workflow for this:

Call execute_operation on the Kestral MCP (registered as \"Kestral\") with
  operationId=\"sync_after_push\",
  params={ branchName: \"${branch}\", summary: \"<what changed>\", prUrl?: \"<PR URL if any>\" },
  explanation=\"<describe what was pushed>\".

Outcomes:
- skipped: nothing to do — OK, continue coding
- synced: done
- needsDecision + unlinked_branch: ask once this session whether to create; do not auto-create
- needsDecision + ambiguous_branch: ask which candidate task to update
- partial: report the failed part and retry the operation named in the response

Skipping when the push had no meaningful progress is OK."

if [[ "$host" == "claude" || "$host" == "codex" ]]; then
  jq -n --arg ctx "$ctx" \
    '{ hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $ctx } }'
else
  jq -n --arg ctx "$ctx" '{ additional_context: $ctx }'
fi
exit 0
