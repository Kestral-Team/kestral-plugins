#!/usr/bin/env bash
# Injects a session-start reminder: full sync when linked, repo_opt_in when unknown.
# Fail-open — always exit 0.
#
# Usage: kestralSessionContext.sh <cursor|claude|codex>

set -euo pipefail

host="${1:-cursor}"
input=$(cat)

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_kestralProjectLinked.sh
source "${script_dir}/_kestralProjectLinked.sh"

if ! command -v git >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
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

branch=$(kestral_git "$repo_root" branch --show-current 2>/dev/null || true)

if [[ -z "$branch" ]]; then
  echo '{}'
  exit 0
fi

link_state="$(kestral_hook_link_state "$repo_root")"

if [[ "$link_state" == "declined" ]]; then
  echo '{}'
  exit 0
fi

plugin_root="${script_dir}/.."
plugin_version=""
for manifest in "${plugin_root}/.claude-plugin/plugin.json" \
  "${plugin_root}/.cursor-plugin/plugin.json" \
  "${plugin_root}/.codex-plugin/plugin.json"; do
  [[ -f "$manifest" ]] || continue
  plugin_version=$(jq -r '.version // empty' "$manifest" 2>/dev/null || true)
  [[ -n "$plugin_version" ]] && break
done

plugin_version_param=""
if [[ -n "$plugin_version" ]]; then
  plugin_version_json=$(jq -n --arg v "$plugin_version" '$v')
  plugin_version_param=", pluginVersion: ${plugin_version_json}"
fi

if [[ "$link_state" == "linked" ]]; then
  ctx="REQUIRED FIRST ACTION: Call execute_operation on the Kestral MCP server (registered as \"Kestral\") with operationId=\"sync_session_workflow\", params={ intent: \"session_start\"${plugin_version_param} }, explanation=\"Loading sync trigger instructions for session on branch ${branch}\". Do this before answering the user's question. The response configures sync triggers for the rest of the session."
else
  git_remote=$(kestral_git "$repo_root" remote get-url origin 2>/dev/null || true)
  git_remote="$(kestral_sanitize_git_remote "$git_remote")"
  prefs_key="$(kestral_repo_prefs_key "$repo_root")"
  prefs_json=$(jq -n --arg k "$prefs_key" '$k')
  if [[ -n "$git_remote" ]]; then
    remote_json=$(jq -n --arg r "$git_remote" '$r')
    params="{ intent: \"repo_opt_in\", gitRemote: ${remote_json}, prefsKey: ${prefs_json}${plugin_version_param} }"
  else
    params="{ intent: \"repo_opt_in\", prefsKey: ${prefs_json}${plugin_version_param} }"
  fi
  ctx="REQUIRED FIRST ACTION: This repo is not opted into Kestral auto-sync yet. Call execute_operation on the Kestral MCP server (registered as \"Kestral\") with operationId=\"sync_session_workflow\", params=${params}, explanation=\"Checking whether to opt this repo into Kestral auto-sync on branch ${branch}\". Follow the returned instructions: upsert ~/.kestral/hook-repos.json (or \$KESTRAL_HOME/hook-repos.json) using the exact prefsKey from params — linked for connected GitHub remotes, skip otherwise — then either run session_start or stay quiet. Do not ask yes/no. Do not run ambient sync or branch lookup until home prefs say linked."
fi

if [[ "$host" == "claude" || "$host" == "codex" ]]; then
  jq -n --arg ctx "$ctx" \
    '{ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $ctx } }'
else
  jq -n --arg ctx "$ctx" '{ additional_context: $ctx }'
fi
exit 0
