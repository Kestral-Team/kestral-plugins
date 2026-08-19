#!/usr/bin/env bash
# Shared marker helpers for Kestral sync hooks.
# Source of truth: ~/.kestral/hook-repos.json (or $KESTRAL_HOME/hook-repos.json).
#
# States (printed by kestral_hook_link_state):
#   linked   — home prefs "linked"
#   declined — home prefs "skip"
#   unknown  — no entry in home prefs

kestral_home_dir() {
  echo "${KESTRAL_HOME:-${HOME}/.kestral}"
}

kestral_realpath() {
  local path="$1"
  if [[ -n "$path" ]] && command -v realpath >/dev/null 2>&1; then
    realpath "$path" 2>/dev/null || echo "$path"
  else
    echo "$path"
  fi
}

kestral_git() {
  local repo_root="${1:-}"
  shift

  if [[ -n "$repo_root" ]]; then
    git -C "$repo_root" "$@"
  else
    git "$@"
  fi
}

kestral_git_toplevel() {
  local path="${1:-}"
  local toplevel

  if [[ -z "$path" ]] || [[ ! -d "$path" ]] || ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  toplevel="$(kestral_git "$path" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$toplevel" ]]; then
    kestral_realpath "$toplevel"
  fi
}

# Resolve the repository open in Cursor without falling back to the plugin install directory.
kestral_resolve_cursor_project_root() {
  local input="${1:-}"
  local candidate root resolved_root=""
  local resolved_count=0

  root="$(kestral_git_toplevel "${CURSOR_PROJECT_DIR:-}")"
  if [[ -n "$root" ]]; then
    echo "$root"
    return 0
  fi

  if [[ -z "$input" ]] || ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    root="$(kestral_git_toplevel "$candidate")"
    [[ -n "$root" ]] || continue
    if [[ "$root" == "$resolved_root" ]]; then
      continue
    fi
    resolved_root="$root"
    resolved_count=$((resolved_count + 1))
    if [[ $resolved_count -gt 1 ]]; then
      return 0
    fi
  done < <(printf '%s' "$input" | jq -r '
    .workspace_roots
    | select(type == "array")
    | .[]
    | select(type == "string")
  ' 2>/dev/null || true)

  if [[ $resolved_count -eq 1 ]]; then
    echo "$resolved_root"
  fi
}

# Strip userinfo from https/http remotes (e.g. https://user:token@host/o/r.git → https://host/o/r.git).
# SSH remotes are unchanged. Safe to embed in hook context / MCP params for repo matching.
kestral_sanitize_git_remote() {
  local remote="$1"
  # shellcheck disable=SC2001
  echo "$remote" | sed -E 's#^(https?://)[^/@]+@#\1#'
}

# True when host is github.com or a github.com-* SSH alias (not lookalikes).
kestral_is_github_host() {
  local host="${1%%:*}"
  host="$(echo "$host" | tr '[:upper:]' '[:lower:]')"
  [[ "$host" == "github.com" || "$host" == github.com-* ]]
}

# Parse a git remote into lowercase owner/repo, or empty if not a GitHub remote.
# Aligned with server parseGitHubGitRemote for common https/ssh/bare cases
# (case-insensitive host / scheme / .git suffix matching).
kestral_parse_github_repo_key() {
  local remote="$1"
  remote="$(echo "$remote" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  if [[ -z "$remote" ]]; then
    return 0
  fi

  local path_part=""
  local host=""
  local nocasematch_was_on=0
  if shopt -q nocasematch; then
    nocasematch_was_on=1
  else
    shopt -s nocasematch
  fi

  if [[ "$remote" =~ ^https?://([^/@]+@)?(www\.)?github\.com/(.+)$ ]]; then
    path_part="${BASH_REMATCH[3]}"
  elif [[ "$remote" =~ ^git@([^:]+):(.+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    if kestral_is_github_host "$host"; then
      path_part="${BASH_REMATCH[2]}"
    fi
  elif [[ "$remote" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    if kestral_is_github_host "$host"; then
      path_part="${BASH_REMATCH[2]}"
    fi
  elif [[ "$remote" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\.git)?/?$ ]]; then
    path_part="$remote"
  fi

  if [[ -z "$path_part" ]]; then
    if [[ $nocasematch_was_on -eq 0 ]]; then
      shopt -u nocasematch
    fi
    return 0
  fi

  path_part="${path_part%%[?#]*}"
  path_part="${path_part%/}"
  # Case-insensitive .git strip (aligned with parseGitHubGitRemote /\.git$/i).
  if [[ "$path_part" =~ ^(.*)\.git$ ]]; then
    path_part="${BASH_REMATCH[1]}"
  fi

  if [[ $nocasematch_was_on -eq 0 ]]; then
    shopt -u nocasematch
  fi

  local owner name
  owner="${path_part%%/*}"
  name="${path_part#*/}"
  name="${name%%/*}"

  if [[ -z "$owner" || -z "$name" || "$owner" == "$path_part" ]]; then
    return 0
  fi
  if [[ "$owner" =~ ^\.+$ || "$name" =~ ^\.+$ ]]; then
    return 0
  fi

  echo "$(echo "${owner}/${name}" | tr '[:upper:]' '[:lower:]')"
}

# Resolve the prefs key for a git repo: owner/repo or dir:<realpath>.
kestral_repo_prefs_key() {
  local repo_root="${1:-}"
  local remote key toplevel

  if command -v git >/dev/null 2>&1; then
    remote="$(kestral_git "$repo_root" remote get-url origin 2>/dev/null || true)"
    remote="$(kestral_sanitize_git_remote "$remote")"
    if [[ -n "$remote" ]]; then
      key="$(kestral_parse_github_repo_key "$remote")"
      if [[ -n "$key" ]]; then
        echo "$key"
        return 0
      fi
    fi
    toplevel="$(kestral_git "$repo_root" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$toplevel" ]]; then
      echo "dir:$(kestral_realpath "$toplevel")"
      return 0
    fi
  fi

  if [[ -n "$repo_root" ]]; then
    echo "dir:$(kestral_realpath "$repo_root")"
  else
    echo "dir:$(pwd -P)"
  fi
}

# Look up linked|skip for a repo in $KESTRAL_HOME/hook-repos.json (empty if missing).
kestral_home_repo_pref() {
  local repo_root="${1:-}"
  local prefs_file key value
  prefs_file="$(kestral_home_dir)/hook-repos.json"
  if [[ ! -f "$prefs_file" ]] || ! command -v jq >/dev/null 2>&1; then
    return 0
  fi
  key="$(kestral_repo_prefs_key "$repo_root")"
  if [[ -z "$key" ]]; then
    return 0
  fi
  value="$(jq -r --arg k "$key" 'if type == "object" then .[$k] // empty else empty end' "$prefs_file" 2>/dev/null || true)"
  if [[ "$value" == "linked" || "$value" == "skip" ]]; then
    echo "$value"
  fi
}

kestral_hook_link_state() {
  local repo_root="${1:-}"
  case "$(kestral_home_repo_pref "$repo_root")" in
    skip)
      echo "declined"
      ;;
    linked)
      echo "linked"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

kestral_project_linked() {
  local repo_root="${1:-}"
  [[ "$(kestral_hook_link_state "$repo_root")" == "linked" ]]
}
