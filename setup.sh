#!/usr/bin/env bash
# Kestral plugin one-shot setup script (macOS and Linux).
#
# Installs the Kestral plugin to Claude Code, Claude Cowork, Codex, and/or Cursor.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
#   bash setup.sh [--app claude-code|claude-cowork|codex|cursor] [--enable-cursor] [--full-reinstall]
#
# Options:
#   --app <targets>       Non-interactive target set (comma-separated: claude-code, claude-cowork, codex, cursor)
#   --enable-cursor       Include Cursor in autodetect and interactive install (off by default until marketplace publish)
#   --full-reinstall      Remove all Kestral plugins, caches, and credentials before reinstalling
#   -h, --help            Show this help
#
# Examples:
#   bash setup.sh --app claude-code
#   bash setup.sh --app codex
#   bash setup.sh --app cursor
#   bash setup.sh --full-reinstall
#   curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash

set -euo pipefail

MARKETPLACE_NAME="kestral-plugins"
MARKETPLACE_REPO="Kestral-Team/kestral-plugins"
MARKETPLACE_GIT_URL="https://github.com/${MARKETPLACE_REPO}.git"
PLUGIN_ID="kestral@${MARKETPLACE_NAME}"
CODEX_APP="/Applications/Codex.app"
CODEX_LOCAL_MARKETPLACE_DIR="${HOME}/.kestral/codex-marketplace"
CURSOR_PLUGIN_LOCAL_NAME="kestral"
CLAUDE_APP="/Applications/Claude.app"
SESSIONS_BASE="${HOME}/Library/Application Support/Claude/local-agent-mode-sessions"
RUBY_BIN=""

# --- Parsed flags ---
APP_FLAG=""
EXPLICIT_APP_FLAG=0
ENABLE_CURSOR=0
FULL_REINSTALL=0

# --- Detection / selection state ---
HAS_GIT=0
HAS_CLAUDE_CLI=0
HAS_CODEX_CLI=0
HAS_CURSOR=0
HAS_DESKTOP_APP=0
HAS_DESKTOP_READY=0
DESKTOP_NOT_READY=0

# bash 3.2-safe indexed arrays (no associative arrays).
# Under set -u, "${name[@]}" on an empty array errors on macOS bash 3.2.
# Prefer an explicit length guard before for-loops when empty is meaningful;
# use ${name[@]+"${name[@]}"} only in small utility scans (e.g. membership checks).
DETECTED_TARGETS=()
SELECTED_TARGETS=()
DESKTOP_ROOTS=()

TARGET_RESULT_CLAUDE=""
TARGET_RESULT_DESKTOP=""
TARGET_RESULT_CODEX=""
TARGET_RESULT_CURSOR=""

DESKTOP_SELECTED_ROOT=""
DESKTOP_BACKUP_SUFFIX=""
DESKTOP_INSTALL_QUIET=0
DESKTOP_RESTART_PENDING=0
DESKTOP_REOPENED=0
CODEX_RESTART_PENDING=0
CODEX_REOPENED=0

# --- Logfile ---

LOGFILE="${HOME}/.kestral/setup.log"
mkdir -p "${HOME}/.kestral"
: > "$LOGFILE"

# --- Usage ---

usage() {
  cat <<EOF
Kestral plugin setup

Configures the remote MCP at app.kestral.ai (macOS and Linux).

Usage:
  curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
  bash setup.sh [--app claude-code|claude-cowork|codex|cursor] [--enable-cursor]

Options:
  --app <targets>       Non-interactive target set (comma-separated: claude-code, claude-cowork, codex, cursor)
  --enable-cursor       Include Cursor in autodetect and interactive install (off by default)
  --full-reinstall      Remove all Kestral plugins, caches, and credentials before reinstalling
  -h, --help            Show this help

Examples:
  bash setup.sh --app claude-code
  bash setup.sh --app codex
  bash setup.sh --app cursor
  bash setup.sh --app claude-code,codex
  bash setup.sh --full-reinstall
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --app)
        shift
        APP_FLAG="${1:-}"
        EXPLICIT_APP_FLAG=1
        [ -n "$APP_FLAG" ] || abort "--app requires a value"
        ;;
      --enable-cursor)
        ENABLE_CURSOR=1
        ;;
      --full-reinstall)
        FULL_REINSTALL=1
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        abort "Unknown option: $1"
        ;;
      *)
        break
        ;;
    esac
    shift
  done
}

_log_verbose() {
  printf '%s\n' "$*" >> "$LOGFILE"
}

# --- Logging helpers ---

_is_tty() {
  [ -t 1 ]
}

_color() {
  if _is_tty; then
    tput setaf "$1" 2>/dev/null || true
  fi
}

_reset_color() {
  if _is_tty; then
    tput sgr0 2>/dev/null || true
  fi
}

# Copy-paste shell commands (cyan when stdout is a TTY).
_cmd_line() {
  _color 6
  printf '  %s\n' "$*"
  _reset_color
}

section() {
  printf '\n'
  if _is_tty; then
    tput bold 2>/dev/null || true
  fi
  printf '%s\n' "$*"
  if _is_tty; then
    tput sgr0 2>/dev/null || true
  fi
  _log_verbose ""
  _log_verbose "=== $* ==="
}

log() {
  _color 4
  printf '  %s\n' "$*"
  _reset_color
  _log_verbose "  $*"
}

ok() {
  _color 2
  printf '  ✓ %s\n' "$*"
  _reset_color
  _log_verbose "  OK: $*"
}

warn() {
  _color 3
  printf '  ⚠ %s\n' "$*"
  _reset_color
  _log_verbose "  WARN: $*"
}

# Log technical detail to file only (not shown to user).
verbose() {
  _log_verbose "  $*"
}

abort() {
  _color 1
  printf '  ✗ %s\n' "$*" >&2
  _reset_color
  printf '  → See the message above and retry after fixing the issue.\n' >&2
  printf '  → Logs: %s\n' "$LOGFILE" >&2
  _log_verbose "  ABORT: $*"
  exit 1
}

abort_with_hint() {
  _color 1
  printf '  ✗ %s\n' "$1" >&2
  _reset_color
  printf '  → %s\n' "$2" >&2
  printf '  → Logs: %s\n' "$LOGFILE" >&2
  _log_verbose "  ABORT: $1 | Hint: $2"
  exit 1
}

# Read a line from /dev/tty when available; returns 1 if no tty.
read_tty() {
  local _prompt="$1"
  local _var="$2"
  if ! { [ -r /dev/tty ] && [ -w /dev/tty ]; } 2>/dev/null; then
    return 1
  fi
  if ! printf '%s' "$_prompt" >/dev/tty 2>/dev/null; then
    return 1
  fi
  # shellcheck disable=SC2229
  if ! IFS= read -r "${_var?}" < /dev/tty 2>/dev/null; then
    return 1
  fi
  return 0
}

# --- Prerequisites ---

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    HAS_GIT=1
    ok "git $(git --version | awk '{print $3}')"
    return 0
  fi

  log "git not found — attempting install..."
  if command -v brew >/dev/null 2>&1; then
    brew install git >>"$LOGFILE" 2>&1 || true
    if command -v git >/dev/null 2>&1; then
      HAS_GIT=1
      ok "git installed via Homebrew"
      return 0
    fi
  fi

  if ! xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools can provide git. Run: xcode-select --install"
  fi

  if [ "$(uname -s)" != "Darwin" ]; then
    log "Install git with your package manager (e.g. apt install git, dnf install git)."
  fi

  HAS_GIT=0
  warn "git is not available."
  return 0
}

_json_write_atomic() {
  local _file="$1"
  local _content="$2"
  local _tmp="${_file}.tmp.$$"
  printf '%s\n' "$_content" > "$_tmp"
  mv "$_tmp" "$_file"
}

ensure_ruby() {
  local _ruby=""
  if command -v ruby >/dev/null 2>&1; then
    _ruby="ruby"
  elif [ -x /usr/bin/ruby ]; then
    _ruby="/usr/bin/ruby"
  fi

  if [ -n "$_ruby" ] && "$_ruby" -e 'require "json"' 2>/dev/null; then
    RUBY_BIN="$_ruby"
    ok "Ruby $("$_ruby" --version | awk '{print $2}')"
    return 0
  fi

  abort_with_hint "Ruby is required for setup." \
    "Ruby comes with macOS. Open Terminal and run: ruby --version"
}

_json_merge_known_marketplace() {
  local _file="$1"
  local _clone_dir="$2"
  local _iso="$3"
  local _result

  _result="$("$RUBY_BIN" -e "$(cat <<'RUBY'
require 'json'
file = ARGV[0]
clone_dir = ARGV[1]
name = ARGV[2]
repo = ARGV[3]
iso = ARGV[4]
data = File.exist?(file) ? JSON.parse(File.read(file)) : {}
data[name] = {
  'source' => { 'source' => 'github', 'repo' => repo },
  'installLocation' => clone_dir,
  'lastUpdated' => iso
}
print JSON.pretty_generate(data) + "\n"
RUBY
)" "$_file" "$_clone_dir" "$MARKETPLACE_NAME" "$MARKETPLACE_REPO" "$_iso")" || return 1
  _json_write_atomic "$_file" "$_result"
}

_json_write_installed_plugin() {
  local _file="$1"
  local _clone_dir="$2"
  local _iso="$3"
  local _sha="$4"
  local _result

  _result="$("$RUBY_BIN" -e "$(cat <<'RUBY'
require 'json'
file = ARGV[0]
clone_dir = ARGV[1]
plugin_id = ARGV[2]
iso = ARGV[3]
sha = ARGV[4]

def convert_v1_to_v2(data)
  return data if data['version'] == 2
  plugins = {}
  (data['plugins'] || {}).each do |id, entry|
    plugins[id] = entry.is_a?(Array) ? entry : [entry]
  end
  { 'version' => 2, 'plugins' => plugins }
end

manifest_path = File.join(clone_dir, '.claude-plugin', 'plugin.json')
version = JSON.parse(File.read(manifest_path))['version']

data = { 'version' => 2, 'plugins' => {} }
data = convert_v1_to_v2(JSON.parse(File.read(file))) if File.exist?(file)

entry = {
  'scope' => 'user',
  'installPath' => clone_dir,
  'version' => version,
  'installedAt' => iso,
  'lastUpdated' => iso,
  'gitCommitSha' => sha,
  'auto' => false
}

existing = data['plugins'][plugin_id]
if existing.is_a?(Array)
  idx = existing.index { |e| e['scope'] == 'user' }
  if idx
    merged = existing[idx].merge(entry)
    merged['installedAt'] = existing[idx]['installedAt'] || iso
    existing[idx] = merged
  else
    existing << entry
  end
  data['plugins'][plugin_id] = existing
else
  data['plugins'][plugin_id] = [entry]
end

print JSON.pretty_generate(data) + "\n"
RUBY
)" "$_file" "$_clone_dir" "$PLUGIN_ID" "$_iso" "$_sha")" || return 1
  _json_write_atomic "$_file" "$_result"
}

_json_enable_cowork_plugin() {
  local _file="$1"
  local _clone_dir="$2"
  local _iso="$3"
  local _result

  _result="$("$RUBY_BIN" -e "$(cat <<'RUBY'
require 'json'
file = ARGV[0]
plugin_id = ARGV[1]
marketplace_name = ARGV[2]
repo = ARGV[3]
clone_dir = ARGV[4]
iso = ARGV[5]

data = { 'enabledPlugins' => {}, 'extraKnownMarketplaces' => {} }
data = JSON.parse(File.read(file)) if File.exist?(file)
data['enabledPlugins'] ||= {}
data['enabledPlugins'][plugin_id] = true
data['extraKnownMarketplaces'] ||= {}
unless data['extraKnownMarketplaces'].key?(marketplace_name)
  data['extraKnownMarketplaces'][marketplace_name] = {
    'source' => { 'source' => 'github', 'repo' => repo, 'name' => marketplace_name },
    'installLocation' => clone_dir,
    'lastUpdated' => iso
  }
end
print JSON.pretty_generate(data) + "\n"
RUBY
)" "$_file" "$PLUGIN_ID" "$MARKETPLACE_NAME" "$MARKETPLACE_REPO" "$_clone_dir" "$_iso")" || return 1
  _json_write_atomic "$_file" "$_result"
}

_claude_marketplace_root() {
  local _candidate
  for _candidate in \
    "${HOME}/.claude/plugins/marketplaces/${MARKETPLACE_NAME}" \
    "${HOME}/.claude/plugins/marketplaces/kestral-plugins"; do
    if [ -d "$_candidate" ]; then
      printf '%s' "$_candidate"
      return 0
    fi
  done
  return 1
}

_codex_marketplace_root() {
  if [ -d "$CODEX_LOCAL_MARKETPLACE_DIR" ]; then
    printf '%s' "$CODEX_LOCAL_MARKETPLACE_DIR"
    return 0
  fi
  local _candidate
  for _candidate in \
    "${HOME}/.codex/plugins/marketplaces/${MARKETPLACE_NAME}" \
    "${HOME}/.codex/plugins/marketplaces/kestral-plugins"; do
    if [ -d "$_candidate" ]; then
      printf '%s' "$_candidate"
      return 0
    fi
  done
  return 1
}

_cursor_plugins_local_dir() {
  printf '%s' "${HOME}/.cursor/plugins/local"
}

_cursor_plugin_install_dir() {
  printf '%s/%s' "$(_cursor_plugins_local_dir)" "$CURSOR_PLUGIN_LOCAL_NAME"
}

# Restore plugin MCP configs in a marketplace clone before git pull so the working tree is clean.
_restore_plugin_mcp_json_in_clone() {
  local _clone_root="${1:-}"
  if [ -n "$_clone_root" ] && [ -d "${_clone_root}/.git" ]; then
    git -C "$_clone_root" checkout -- .mcp.json 2>/dev/null || true
    git -C "$_clone_root" checkout -- .cursor-plugin/mcp.json 2>/dev/null || true
  fi
}

_patch_kestral_mcp_json_under() {
  local _root="$1"
  local _rewrite_fn="$2"
  local _mcp_file _dir
  if [ ! -d "$_root" ]; then
    return 0
  fi
  while IFS= read -r _mcp_file; do
    _dir="$(dirname "$_mcp_file")"
    "$_rewrite_fn" "$_dir"
  done < <(find "$_root" \( -path '*kestral-plugins*' -o -path '*kestral@kestral-plugins*' \) -name '.mcp.json' 2>/dev/null)
}

REMOTE_MCP_URL="https://app.kestral.ai/mcp"

_rewrite_plugin_mcp_json_remote() {
  local _plugin_root="$1"
  local _content _mcp_file
  _content=$(printf '%s\n' "{
  \"mcpServers\": {
    \"Kestral\": {
      \"type\": \"http\",
      \"url\": \"${REMOTE_MCP_URL}\"
    }
  },
  \"mcp_servers\": {
    \"Kestral\": {
      \"type\": \"http\",
      \"url\": \"${REMOTE_MCP_URL}\"
    }
  }
}")
  for _mcp_file in "${_plugin_root}/.mcp.json" "${_plugin_root}/.cursor-plugin/mcp.json"; do
    if [ -f "$_mcp_file" ]; then
      _json_write_atomic "$_mcp_file" "$_content"
      verbose "Rewrote ${_mcp_file} → ${REMOTE_MCP_URL}"
    fi
  done
}

_patch_all_installed_mcp_json() {
  _patch_kestral_mcp_json_under "${HOME}/.claude" "_rewrite_plugin_mcp_json_remote"
  _patch_kestral_mcp_json_under "${HOME}/.codex" "_rewrite_plugin_mcp_json_remote"
  _patch_kestral_mcp_json_under "${HOME}/.kestral" "_rewrite_plugin_mcp_json_remote"
  if [ -d "$SESSIONS_BASE" ]; then
    _patch_kestral_mcp_json_under "$SESSIONS_BASE" "_rewrite_plugin_mcp_json_remote"
  fi
}

# --- App detection ---

_enumerate_desktop_roots() {
  DESKTOP_ROOTS=()

  if [ ! -d "$SESSIONS_BASE" ]; then
    return 0
  fi

  local _account _org _acc_name
  for _account in "$SESSIONS_BASE"/*; do
    [ -d "$_account" ] || continue
    _acc_name="$(basename "$_account")"
    if [ "$_acc_name" = "skills-plugin" ]; then
      continue
    fi
    for _org in "$_account"/*; do
      [ -d "$_org" ] || continue
      DESKTOP_ROOTS+=("${_acc_name}/$(basename "$_org")")
    done
  done
}

detect_apps() {
  HAS_CLAUDE_CLI=0
  HAS_CODEX_CLI=0
  HAS_CURSOR=0
  HAS_DESKTOP_APP=0
  HAS_DESKTOP_READY=0
  DESKTOP_NOT_READY=0

  if command -v claude >/dev/null 2>&1; then
    HAS_CLAUDE_CLI=1
  fi

  if _codex_bin >/dev/null; then
    HAS_CODEX_CLI=1
  fi

  if [ -d "${HOME}/.cursor" ] || [ -d "/Applications/Cursor.app" ]; then
    HAS_CURSOR=1
  fi

  if [ -d "$CLAUDE_APP" ]; then
    HAS_DESKTOP_APP=1
    _enumerate_desktop_roots
    if [ "${#DESKTOP_ROOTS[@]}" -gt 0 ]; then
      HAS_DESKTOP_READY=1
    else
      DESKTOP_NOT_READY=1
    fi
  fi
}

_add_target_if_missing() {
  local _t="$1"
  local _existing
  for _existing in ${SELECTED_TARGETS[@]+"${SELECTED_TARGETS[@]}"}; do
    if [ "$_existing" = "$_t" ]; then
      return 0
    fi
  done
  SELECTED_TARGETS+=("$_t")
}

_target_display_name() {
  case "$1" in
    claude-code)
      printf '%s' "Claude Code"
      ;;
    claude-desktop)
      printf '%s' "Claude Cowork"
      ;;
    codex)
      printf '%s' "Codex"
      ;;
    cursor)
      printf '%s' "Cursor"
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

_target_detection_blurb() {
  case "$1" in
    claude-code)
      if [ "$HAS_DESKTOP_READY" -eq 1 ]; then
        printf '%s' "claude CLI found; Claude Code Desktop also signed in"
      elif [ "$HAS_DESKTOP_APP" -eq 1 ]; then
        printf '%s' "claude CLI found; Claude Code Desktop installed"
      else
        printf '%s' "claude CLI found"
      fi
      ;;
    claude-desktop)
      printf 'signed in, %s account(s)' "${#DESKTOP_ROOTS[@]}"
      ;;
    codex)
      printf '%s' "codex CLI found"
      ;;
    cursor)
      printf '%s' "Cursor app installed"
      ;;
    *)
      printf '%s' "detected"
      ;;
  esac
}

_populate_detected_targets() {
  DETECTED_TARGETS=()

  if [ "$HAS_CLAUDE_CLI" -eq 1 ]; then
    DETECTED_TARGETS+=("claude-code")
  fi
  if [ "$HAS_DESKTOP_READY" -eq 1 ]; then
    DETECTED_TARGETS+=("claude-desktop")
  fi
  if [ "$HAS_CODEX_CLI" -eq 1 ]; then
    DETECTED_TARGETS+=("codex")
  fi
  if [ "$HAS_CURSOR" -eq 1 ] && [ "$ENABLE_CURSOR" -eq 1 ]; then
    DETECTED_TARGETS+=("cursor")
  fi
}

_print_detection_summary() {
  local _idx=0
  local _target _name _blurb

  if [ "${#DETECTED_TARGETS[@]}" -gt 0 ]; then
    for _target in "${DETECTED_TARGETS[@]}"; do
      _idx=$((_idx + 1))
      _name="$(_target_display_name "$_target")"
      _blurb="$(_target_detection_blurb "$_target")"
      printf '    [%s] %s (%s)\n' "$_idx" "$_name" "$_blurb"
    done
  fi

  if [ "$DESKTOP_NOT_READY" -eq 1 ]; then
    printf '    [ ] Claude Cowork (installed but not signed in — open it, sign in, re-run)\n'
  fi

  if [ "${#DETECTED_TARGETS[@]}" -eq 0 ] && [ "$DESKTOP_NOT_READY" -eq 0 ]; then
    printf '  (none detected)\n'
  fi
}

_build_target_selection_prompt() {
  local _prompt="Install Kestral to: "
  local _idx=0
  local _target _name

  if [ "${#DETECTED_TARGETS[@]}" -gt 0 ]; then
    for _target in "${DETECTED_TARGETS[@]}"; do
      _idx=$((_idx + 1))
      _name="$(_target_display_name "$_target")"
      _prompt="${_prompt}[${_idx}] ${_name}  "
    done
  fi

  _prompt="${_prompt}— Enter = all, or type numbers (e.g. \"1\"): "
  printf '%s' "$_prompt"
}

_select_targets_from_choice() {
  local _choice="$1"
  local _digit _index _target

  for _digit in $(printf '%s' "$_choice" | grep -o '[0-9]' || true); do
    _index=$((_digit))
    if [ "$_index" -ge 1 ] && [ "$_index" -le "${#DETECTED_TARGETS[@]}" ]; then
      _target="${DETECTED_TARGETS[$((_index - 1))]}"
      _add_target_if_missing "$_target"
    fi
  done
}

_parse_app_flag() {
  local _flag="$1"
  local _part
  # shellcheck disable=SC2086
  for _part in $(printf '%s' "$_flag" | tr ',' ' '); do
    case "$_part" in
      claude-code)
        _add_target_if_missing "claude-code"
        ;;
      claude-cowork | claude-desktop)
        _add_target_if_missing "claude-desktop"
        ;;
      codex)
        _add_target_if_missing "codex"
        ;;
      cursor)
        _add_target_if_missing "cursor"
        ;;
      *)
        abort "Unknown --app target: $_part (use claude-code, claude-cowork, codex, or cursor)"
        ;;
    esac
  done
}

select_targets() {
  SELECTED_TARGETS=()
  _populate_detected_targets

  _print_detection_summary

  if [ "$EXPLICIT_APP_FLAG" -eq 1 ]; then
    _parse_app_flag "$APP_FLAG"
    if [ "${#SELECTED_TARGETS[@]}" -gt 0 ]; then
      local _t
      for _t in "${SELECTED_TARGETS[@]}"; do
        if [ "$_t" = "claude-code" ] && [ "$HAS_CLAUDE_CLI" -eq 0 ]; then
          : # ensure_claude_cli handles --app claude-code with missing CLI
        elif [ "$_t" = "claude-desktop" ]; then
          if [ "$HAS_DESKTOP_APP" -eq 0 ]; then
            abort_with_hint "Claude Cowork is not installed." \
              "Install Claude Cowork from https://claude.ai/download, sign in, then re-run."
          fi
          if [ "$HAS_DESKTOP_READY" -eq 0 ]; then
            abort_with_hint "Claude Cowork is installed but no Cowork session was found." \
              "Open Claude Cowork, sign in, then re-run this script."
          fi
        fi
      done
    fi
    return 0
  fi

  if [ "${#DETECTED_TARGETS[@]}" -eq 0 ]; then
    abort_with_hint "No supported apps detected." \
      "Install Claude Code (https://claude.ai/code), Claude Cowork (https://claude.ai/download), Codex (https://codex.openai.com), or Cursor (https://cursor.com), then re-run."
  fi

  # Default: all detected targets pre-selected
  local _choice=""
  local _prompt
  _prompt="$(_build_target_selection_prompt)"

  if read_tty "$_prompt" _choice; then
    _choice="$(printf '%s' "$_choice" | tr -d '[:space:]')"
    if [ -z "$_choice" ]; then
      SELECTED_TARGETS=("${DETECTED_TARGETS[@]}")
    else
      _select_targets_from_choice "$_choice"
      if [ "${#SELECTED_TARGETS[@]}" -eq 0 ]; then
        abort "No valid targets selected."
      fi
    fi
  else
    warn "No TTY — installing to all detected targets."
    SELECTED_TARGETS=("${DETECTED_TARGETS[@]}")
  fi
}

# --- Claude Code path ---

ensure_claude_cli() {
  if command -v claude >/dev/null 2>&1; then
    ok "claude CLI $(claude --version 2>/dev/null | head -1 || echo found)"
    return 0
  fi

  log "claude CLI not found."
  local _answer=""
  if read_tty "Install Claude Code via the official installer? [Y/n] " _answer; then
    case "$_answer" in
      [nN] | [nN][oO])
        _print_claude_cli_manual_install
        warn "Claude Code CLI is required for --app claude-code."
        return 1
        ;;
    esac
    log "Running official Claude Code installer..."
    curl -fsSL https://claude.ai/install.sh | bash
  else
    _print_claude_cli_manual_install
    warn "Claude Code CLI is required for --app claude-code."
    return 1
  fi

  # Refresh PATH for current shell
  export PATH="${HOME}/.local/bin:${HOME}/.claude/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"
  hash -r 2>/dev/null || true

  if ! command -v claude >/dev/null 2>&1; then
    _print_claude_cli_manual_install
    warn "claude CLI still not found after install."
    return 1
  fi
  ok "claude CLI installed"
}

_print_claude_cli_manual_install() {
  cat <<EOF
Install Claude Code, then re-run this script:

  curl -fsSL https://claude.ai/install.sh | bash

Or via npm:
  npm install -g @anthropic-ai/claude-code
EOF
}

_run_claude_cmd() {
  claude "$@" 2>&1
}

ensure_marketplace() {
  log "Registering Kestral marketplace..."
  local _output _rc
  set +e
  _output="$(_run_claude_cmd plugin marketplace add "$MARKETPLACE_REPO")"
  _rc=$?
  set -e
  verbose "marketplace add output: $_output (rc=$_rc)"

  if [ "$_rc" -eq 0 ] && ! printf '%s' "$_output" | grep -qi 'already'; then
    ok "Kestral marketplace registered"
    return 0
  fi

  if printf '%s' "$_output" | grep -qi 'already'; then
    log "Already registered — checking for updates..."
    set +e
    _output="$(_run_claude_cmd plugin marketplace update "$MARKETPLACE_NAME")"
    _rc=$?
    set -e
    verbose "marketplace update output: $_output (rc=$_rc)"
    if [ "$_rc" -eq 0 ]; then
      ok "Kestral marketplace up to date"
      return 0
    fi
  fi

  if printf '%s' "$_output" | grep -qi 'Host key verification failed'; then
    warn "GitHub connection failed (SSH host key issue)."
    printf '  → Run: ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts\n' >&2
    printf '  → Or: git config --global url."https://github.com/".insteadOf git@github.com:\n' >&2
    return 1
  fi

  verbose "marketplace failure output: $_output"
  warn "Failed to register marketplace."
  return 1
}

install_or_update_plugin() {
  log "Installing Kestral plugin..."
  local _output _rc
  set +e
  _output="$(_run_claude_cmd plugin install "$PLUGIN_ID")"
  _rc=$?
  set -e
  verbose "plugin install output: $_output (rc=$_rc)"

  if [ "$_rc" -eq 0 ]; then
    ok "Kestral plugin installed"
    return 0
  fi

  if printf '%s' "$_output" | grep -qi 'already installed'; then
    ok "Kestral plugin is up to date"
    return 0
  fi

  verbose "install failure output: $_output"
  warn "Failed to install Kestral plugin."
  printf '  → Existing installs were left untouched. Re-run this script after fixing the error, or uninstall manually first.\n' >&2
  return 1
}

_is_cowork_selected() {
  local _t
  for _t in ${SELECTED_TARGETS[@]+"${SELECTED_TARGETS[@]}"}; do
    if [ "$_t" = "claude-desktop" ]; then
      return 0
    fi
  done
  return 1
}

_is_claude_code_selected() {
  local _t
  for _t in ${SELECTED_TARGETS[@]+"${SELECTED_TARGETS[@]}"}; do
    if [ "$_t" = "claude-code" ]; then
      return 0
    fi
  done
  return 1
}

_desktop_app_name() {
  if _is_claude_code_selected && _is_cowork_selected; then
    printf 'Claude Desktop'
  elif _is_claude_code_selected; then
    printf 'Claude Code Desktop'
  else
    printf 'Claude Cowork'
  fi
}

_prompt_restart_cowork_for_claude_code() {
  if [ "$HAS_DESKTOP_APP" -eq 0 ]; then
    return 0
  fi
  if _is_cowork_selected; then
    return 0
  fi
  if ! pgrep -x Claude >/dev/null 2>&1; then
    return 0
  fi
  local _name
  _name="$(_desktop_app_name)"
  local _answer=""
  if read_tty "  ${_name} is also running. Restart it to pick up plugin changes? [Y/n] " _answer; then
    case "$_answer" in
      [nN] | [nN][oO])
        warn "${_name} is running — restart it manually to pick up plugin changes."
        return 0
        ;;
    esac
    log "Restarting ${_name}..."
    osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
    local _wait=0
    while pgrep -x Claude >/dev/null 2>&1; do
      sleep 1
      _wait=$((_wait + 1))
      if [ "$_wait" -ge 10 ]; then
        warn "${_name} didn't stop in time — proceeding anyway."
        return 0
      fi
    done
    ok "${_name} stopped"
    _reopen_claude_desktop || true
  else
    if [ "$HAS_DESKTOP_APP" -eq 1 ] && [ "${DESKTOP_REOPENED:-0}" -ne 1 ]; then
      warn "${_name} detected — restart it manually to pick up plugin changes."
    fi
  fi
}

print_claude_success() {
  cat <<EOF

Claude Code: Kestral plugin is ready (connects to Kestral at ${REMOTE_MCP_URL}).
  1. Fully quit and reopen Claude Code if it was running (required to reload plugin content).
  2. Run: claude
  3. In chat: /kestral:kestral-setup
EOF

  if [ "$HAS_DESKTOP_APP" -eq 1 ] && [ "${DESKTOP_REOPENED:-0}" -ne 1 ] && ! _is_cowork_selected; then
    printf '  → Also restart Claude Code Desktop if it was running, so it picks up the updated plugin.\n'
  fi
}

install_to_claude_code() {
  if [ "$HAS_GIT" -eq 0 ]; then
    warn "Claude Code requires git. Install via: xcode-select --install or brew install git"
    return 1
  fi

  if ! ensure_claude_cli; then
    return 1
  fi

  _restore_plugin_mcp_json_in_clone "$(_claude_marketplace_root 2>/dev/null || true)"
  if ! ensure_marketplace; then
    return 1
  fi
  if ! install_or_update_plugin; then
    return 1
  fi
  _patch_all_installed_mcp_json
  _prompt_restart_cowork_for_claude_code
  print_claude_success
}

# --- Claude Cowork path ---

_print_desktop_gui_fallback() {
  cat <<'EOF'

Claude Cowork manual install (GUI fallback):
  1. Open the Customize menu and go to the Plugins tab.
  2. In Personal plugins, click +, then select Add marketplace.
  3. Choose Add from a repository (sync a marketplace from a GitHub repository or git URL).
  4. In the URL field, enter Kestral-Team/kestral-plugins, then click Sync.
  5. Click + on the Kestral card to install the plugin.
  6. If the This plugin includes local MCP servers dialog appears, click Continue to install the MCP server.
  7. The Kestral MCP connector registers with the plugin. Check Customize → Connectors; if it is missing, fully quit and restart Cowork.
  8. The first Kestral tool call opens a browser window for OAuth sign-in.
  9. In Cowork, run /kestral:kestral-setup to connect your workspace and start onboarding.
EOF
}

_reopen_claude_desktop() {
  local _name
  _name="$(_desktop_app_name)"
  if [ ! -d "$CLAUDE_APP" ]; then
    warn "${_name} not found at $CLAUDE_APP — open it manually after install."
    return 1
  fi
  log "Reopening ${_name}..."
  if open "$CLAUDE_APP" >> "$LOGFILE" 2>&1; then
    DESKTOP_REOPENED=1
    ok "${_name} reopened"
    return 0
  fi
  warn "Couldn't reopen ${_name} automatically — open it manually."
  return 1
}

_finish_desktop_restart() {
  if [ "$DESKTOP_RESTART_PENDING" -eq 1 ] && [ "$DESKTOP_REOPENED" -eq 0 ]; then
    _reopen_claude_desktop || true
  fi
}

_reopen_codex() {
  if [ ! -d "$CODEX_APP" ]; then
    warn "Codex not found at $CODEX_APP — open it manually after install."
    return 1
  fi
  log "Reopening Codex..."
  if open "$CODEX_APP" >> "$LOGFILE" 2>&1; then
    CODEX_REOPENED=1
    ok "Codex reopened"
    return 0
  fi
  warn "Couldn't reopen Codex automatically — open it manually."
  return 1
}

_finish_codex_restart() {
  if [ "$CODEX_RESTART_PENDING" -eq 1 ] && [ "$CODEX_REOPENED" -eq 0 ]; then
    _reopen_codex || true
  fi
}

warn_if_desktop_running() {
  if pgrep -x Claude >/dev/null 2>&1; then
    local _name
    _name="$(_desktop_app_name)"
    local _answer=""
    if read_tty "  ${_name} is running. Restart now to load the Kestral plugin? [Y/n] " _answer; then
      case "$_answer" in
        [nN] | [nN][oO])
          warn "Proceeding while ${_name} is running — restart after install to load the Kestral plugin."
          return 0
          ;;
      esac
      log "Restarting ${_name}..."
      osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
      local _wait=0
      while pgrep -x Claude >/dev/null 2>&1; do
        sleep 1
        _wait=$((_wait + 1))
        if [ "$_wait" -ge 10 ]; then
          warn "${_name} didn't stop in time — proceeding anyway."
          return 0
        fi
      done
      DESKTOP_RESTART_PENDING=1
      ok "${_name} stopped — will reopen after install completes."
    else
      warn "${_name} is running — restart after install to load the Kestral plugin."
    fi
  fi
}

_desktop_org_dir() {
  printf '%s/%s' "$SESSIONS_BASE" "$DESKTOP_SELECTED_ROOT"
}

_desktop_cowork_plugins_dir() {
  printf '%s/cowork_plugins' "$(_desktop_org_dir)"
}

_desktop_marketplace_clone_dir() {
  printf '%s/marketplaces/%s' "$(_desktop_cowork_plugins_dir)" "$MARKETPLACE_NAME"
}

_backup_json_if_exists() {
  local _file="$1"
  if [ -f "$_file" ]; then
    cp -p "$_file" "${_file}${DESKTOP_BACKUP_SUFFIX}"
  fi
}

_restore_desktop_backups() {
  local _dir _org_dir
  _dir="$(_desktop_cowork_plugins_dir)"
  _org_dir="$(_desktop_org_dir)"
  local _f
  for _f in \
    "${_dir}/known_marketplaces.json" \
    "${_dir}/installed_plugins.json" \
    "${_org_dir}/cowork_settings.json"; do
    if [ -f "${_f}${DESKTOP_BACKUP_SUFFIX}" ]; then
      mv "${_f}${DESKTOP_BACKUP_SUFFIX}" "$_f"
    else
      rm -f "$_f"
    fi
  done
}

clone_or_update_marketplace() {
  local _clone_dir
  _clone_dir="$(_desktop_marketplace_clone_dir)"

  if ! _fetch_marketplace_to_dir "$_clone_dir" "$DESKTOP_INSTALL_QUIET"; then
    return 1
  fi

  _finalize_marketplace_clone "$_clone_dir"
}

_fetch_marketplace_to_dir() {
  local _clone_dir="$1"
  local _quiet="${2:-0}"

  mkdir -p "$(dirname "$_clone_dir")"

  if [ -d "$_clone_dir/.git" ]; then
    if [ "$_quiet" -eq 1 ]; then
      verbose "Updating Kestral marketplace at ${_clone_dir}..."
    else
      log "Updating Kestral marketplace..."
    fi
    verbose "git pull --ff-only in $_clone_dir"
    _restore_plugin_mcp_json_in_clone "$_clone_dir"
    if ! git -C "$_clone_dir" diff --quiet 2>/dev/null || ! git -C "$_clone_dir" diff --cached --quiet 2>/dev/null; then
      warn "Marketplace has local modifications — can't update automatically."
      verbose "Dirty working tree in $_clone_dir"
      printf '  → Delete the folder and re-run, or use the GUI steps below:\n' >&2
      verbose "Remedy: rm -rf \"$_clone_dir\" && re-run"
      _print_desktop_gui_fallback
      return 1
    fi
    if ! git -C "$_clone_dir" pull --ff-only >> "$LOGFILE" 2>&1; then
      warn "Couldn't update marketplace (history may have diverged)."
      verbose "git pull --ff-only failed in $_clone_dir"
      printf '  → Delete the folder and re-run, or use the GUI steps below:\n' >&2
      _print_desktop_gui_fallback
      return 1
    fi
    if [ "$_quiet" -eq 1 ]; then
      verbose "Kestral marketplace updated at ${_clone_dir}"
    else
      ok "Kestral marketplace updated"
    fi
  else
    if [ "$_quiet" -eq 1 ]; then
      verbose "Cloning Kestral marketplace to ${_clone_dir}..."
    else
      log "Installing Kestral marketplace..."
    fi
    verbose "git clone $MARKETPLACE_GIT_URL $_clone_dir"
    if ! git clone "$MARKETPLACE_GIT_URL" "$_clone_dir" >> "$LOGFILE" 2>&1; then
      if [ "$_quiet" -eq 1 ]; then
        verbose "Failed to download marketplace to ${_clone_dir}"
      else
        warn "Failed to download marketplace."
      fi
      return 1
    fi
    if [ "$_quiet" -eq 1 ]; then
      verbose "Kestral marketplace cloned to ${_clone_dir}"
    else
      ok "Kestral marketplace installed"
    fi
  fi

  return 0
}

_finalize_marketplace_clone() {
  local _clone_dir="$1"
  _rewrite_plugin_mcp_json_remote "$_clone_dir"
  _write_plugin_server_json "$_clone_dir"
}

_copy_marketplace_to_root() {
  local _source_dir="$1"
  local _dest_dir

  _dest_dir="$(_desktop_marketplace_clone_dir)"
  mkdir -p "$(dirname "$_dest_dir")"
  rm -rf "$_dest_dir"
  mkdir -p "$_dest_dir"

  if ! cp -R "${_source_dir}/." "$_dest_dir/"; then
    verbose "Failed to copy marketplace to ${_dest_dir}"
    return 1
  fi

  verbose "Copied marketplace to ${_dest_dir}"
  return 0
}

_register_marketplace() {
  local _plugins_dir _known _clone_dir _iso
  _plugins_dir="$(_desktop_cowork_plugins_dir)"
  _known="${_plugins_dir}/known_marketplaces.json"
  _clone_dir="$(_desktop_marketplace_clone_dir)"
  mkdir -p "$_plugins_dir"
  _backup_json_if_exists "$_known"

  _iso="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"

  _json_merge_known_marketplace "$_known" "$_clone_dir" "$_iso" || return 1
  verbose "Registered marketplace in known_marketplaces.json"
}

_write_installed_plugin() {
  local _plugins_dir _installed _clone_dir _iso _sha
  _plugins_dir="$(_desktop_cowork_plugins_dir)"
  _installed="${_plugins_dir}/installed_plugins.json"
  _clone_dir="$(_desktop_marketplace_clone_dir)"
  _backup_json_if_exists "$_installed"

  _iso="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
  if ! _sha="$(git -C "$_clone_dir" rev-parse HEAD)"; then
    return 1
  fi

  _json_write_installed_plugin "$_installed" "$_clone_dir" "$_iso" "$_sha" || return 1
  verbose "Wrote installed_plugins.json (schema v2)"
}

_enable_plugin() {
  local _settings _iso
  _settings="$(_desktop_org_dir)/cowork_settings.json"
  _backup_json_if_exists "$_settings"
  _iso="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"

  _json_enable_cowork_plugin "$_settings" "$(_desktop_marketplace_clone_dir)" "$_iso" || return 1
  verbose "Enabled plugin in cowork_settings.json"
}

_write_plugin_server_json() {
  local _plugin_root="$1"
  local _manifest="${_plugin_root}/.claude-plugin/plugin.json"
  local _version _content

  if [ -f "$_manifest" ]; then
    _version="$("$RUBY_BIN" -e 'require "json"; print JSON.parse(File.read(ARGV[0]))["version"]' "$_manifest" 2>/dev/null || true)"
  fi
  _version="${_version:-0.0.0}"

  _content=$(printf '%s\n' "{
  \"\$schema\": \"https://static.modelcontextprotocol.io/schemas/2025-09-29/server.schema.json\",
  \"name\": \"ai.kestral.app/mcp\",
  \"title\": \"Kestral MCP Server\",
  \"description\": \"Connect Claude to your Kestral workspace for tasks, context, and project setup.\",
  \"repository\": {
    \"url\": \"https://github.com/${MARKETPLACE_REPO}\",
    \"source\": \"github\"
  },
  \"version\": \"${_version}\",
  \"remotes\": [
    {
      \"type\": \"streamable-http\",
      \"url\": \"${REMOTE_MCP_URL}\"
    }
  ]
}")
  _json_write_atomic "${_plugin_root}/server.json" "$_content"
  verbose "Wrote server.json (${REMOTE_MCP_URL})"
}

print_desktop_success() {
  local _name
  _name="$(_desktop_app_name)"
  printf '\n%s: Kestral plugin files are installed (connects to Kestral at %s).\n' "$_name" "$REMOTE_MCP_URL"
  local _step=1
  if [ "$DESKTOP_REOPENED" -ne 1 ]; then
    printf '  %d. Fully quit and reopen %s (required — running sessions won'\''t see disk edits).\n' "$_step" "$_name"
    _step=$((_step + 1))
  fi
  printf '  %d. Start a new task (+ New task — running tasks never reload plugin content).\n' "$_step"
  _step=$((_step + 1))
  printf '  %d. In Cowork, run: /kestral:kestral-setup\n' "$_step"

  if [ "$TARGET_RESULT_CLAUDE" = "installed" ]; then
    printf '  → Also restart the Claude Code CLI if it was running, so it picks up the updated plugin.\n'
  fi
}

_install_desktop_for_root() {
  if [ -z "$DESKTOP_BACKUP_SUFFIX" ]; then
    DESKTOP_BACKUP_SUFFIX=".kestral-backup-${DESKTOP_SELECTED_ROOT//\//-}"
  fi

  if ! clone_or_update_marketplace; then
    return 1
  fi

  _configure_desktop_for_root
}

_configure_desktop_for_root() {
  if ! _register_marketplace; then
    _restore_desktop_backups
    return 1
  fi
  if ! _write_installed_plugin; then
    _restore_desktop_backups
    return 1
  fi
  if ! _enable_plugin; then
    _restore_desktop_backups
    return 1
  fi

  local _dir _org_dir
  _dir="$(_desktop_cowork_plugins_dir)"
  _org_dir="$(_desktop_org_dir)"
  rm -f "${_dir}/known_marketplaces.json${DESKTOP_BACKUP_SUFFIX}" \
        "${_dir}/installed_plugins.json${DESKTOP_BACKUP_SUFFIX}" \
        "${_org_dir}/cowork_settings.json${DESKTOP_BACKUP_SUFFIX}" 2>/dev/null || true
}

_install_desktop_roots_from_shared() {
  local _source_dir="$1"
  local _root_count="$2"
  local _tmpdir _root _pids _pid _job_root _job_idx _root_idx _succeeded=0

  _tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/kestral-desktop-install.XXXXXX")"
  _pids=()
  log "Configuring ${_root_count} Cowork accounts..." >&2
  verbose "Shared marketplace stage: $_source_dir"

  _root_idx=0
  for _root in "${DESKTOP_ROOTS[@]}"; do
    _job_root="$_root"
    _job_idx="$_root_idx"
    (
      DESKTOP_SELECTED_ROOT="$_job_root"
      DESKTOP_BACKUP_SUFFIX=".kestral-backup-${_job_root//\//-}"
      if _copy_marketplace_to_root "$_source_dir" && _configure_desktop_for_root; then
        : > "${_tmpdir}/ok-${_job_idx}"
      else
        printf '%s\n' "$_job_root" > "${_tmpdir}/fail-${_job_idx}"
      fi
    ) &
    _pids+=($!)
    _root_idx=$((_root_idx + 1))
  done

  for _pid in "${_pids[@]}"; do
    wait "$_pid" || true
  done

  _root_idx=0
  while [ "$_root_idx" -lt "$_root_count" ]; do
    if [ -f "${_tmpdir}/ok-${_root_idx}" ]; then
      _succeeded=$((_succeeded + 1))
      verbose "Installed for ${DESKTOP_ROOTS[$_root_idx]}"
    else
      warn "Could not install for account ${DESKTOP_ROOTS[$_root_idx]} — continuing with remaining accounts." >&2
    fi
    _root_idx=$((_root_idx + 1))
  done
  rm -rf "$_tmpdir"

  printf '%s' "$_succeeded"
}

install_to_claude_desktop() {
  if [ "$HAS_GIT" -eq 0 ]; then
    warn "Claude Cowork requires git. Install via: xcode-select --install or brew install git"
    _print_desktop_gui_fallback
    return 1
  fi

  if ! ensure_ruby; then
    _print_desktop_gui_fallback
    return 1
  fi

  warn_if_desktop_running

  local _succeeded=0
  local _root_count="${#DESKTOP_ROOTS[@]}"
  local _stage_dir=""

  if [ "$_root_count" -gt 1 ]; then
    _stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/kestral-desktop-marketplace.XXXXXX")"
    log "Downloading Kestral marketplace..."
    verbose "Marketplace stage dir: $_stage_dir"

    if ! _fetch_marketplace_to_dir "$_stage_dir" 0; then
      rm -rf "$_stage_dir"
      warn "Desktop install failed — could not download marketplace."
      printf '  → Logs: %s\n' "$LOGFILE" >&2
      _print_desktop_gui_fallback
      _finish_desktop_restart
      return 1
    fi

    _finalize_marketplace_clone "$_stage_dir"
    ok "Kestral marketplace ready"

    _succeeded="$(_install_desktop_roots_from_shared "$_stage_dir" "$_root_count")"
    rm -rf "$_stage_dir"

    if [ "$_succeeded" -gt 0 ]; then
      ok "Configured ${_succeeded}/${_root_count} Cowork accounts"
    fi
  else
    DESKTOP_SELECTED_ROOT="${DESKTOP_ROOTS[0]}"
    verbose "Installing to account ${DESKTOP_SELECTED_ROOT} (1/1)"

    if _install_desktop_for_root; then
      _succeeded=1
      verbose "Installed for ${DESKTOP_SELECTED_ROOT}"
    else
      warn "Could not install for account ${DESKTOP_SELECTED_ROOT}."
    fi
  fi

  if [ "$_succeeded" -eq 0 ]; then
    warn "Desktop install failed for all accounts — restoring previous state..."
    printf '  → Logs: %s\n' "$LOGFILE" >&2
    _print_desktop_gui_fallback
    _finish_desktop_restart
    return 1
  fi

  ok "Plugin configured for ${_succeeded}/${_root_count} account(s)"
  _finish_desktop_restart
  print_desktop_success
}

# --- Codex path ---

_codex_bin() {
  local _bin
  _bin="$(command -v codex 2>/dev/null || true)"
  if [ -n "$_bin" ]; then
    printf '%s' "$_bin"
    return 0
  fi

  local _bundled="${CODEX_APP}/Contents/Resources/codex"
  if [ -x "$_bundled" ]; then
    printf '%s' "$_bundled"
    return 0
  fi

  return 1
}

_print_codex_install_instructions() {
  cat <<EOF
Install Codex Desktop, then re-run this script:

  Download from https://codex.openai.com
EOF
}

_print_codex_gui_fallback() {
  cat <<'EOF'

Codex manual install (GUI fallback):
  1. Open Plugins, click More, then select Add more.
  2. In the repository field, enter Kestral-Team/kestral-plugins.
  3. Click More again, then find Kestral Plugins.
  4. Click + in the Productivity section for the Kestral plugin.
  5. Fully quit and reopen Codex (required — running sessions won't reload plugin content).
  6. In a new thread, run $kestral-setup to connect your workspace.
EOF
}

warn_if_codex_running() {
  if pgrep -x Codex >/dev/null 2>&1; then
    local _answer=""
    if read_tty "  Codex is running. Restart now to load the Kestral plugin? [Y/n] " _answer; then
      case "$_answer" in
        [nN] | [nN][oO])
          warn "Proceeding while Codex is running — restart after install to load the Kestral plugin."
          return 0
          ;;
      esac
      log "Restarting Codex..."
      osascript -e 'tell application "Codex" to quit' 2>/dev/null || true
      local _wait=0
      while pgrep -x Codex >/dev/null 2>&1; do
        sleep 1
        _wait=$((_wait + 1))
        if [ "$_wait" -ge 10 ]; then
          warn "Codex didn't stop in time — proceeding anyway."
          return 0
        fi
      done
      CODEX_RESTART_PENDING=1
      ok "Codex stopped — will reopen after install completes."
    else
      warn "Codex is running — restart after install to load the Kestral plugin."
    fi
  fi
}

ensure_codex_cli() {
  local _bin _version
  if ! _bin=$(_codex_bin); then
    _print_codex_install_instructions
    return 1
  fi

  _version=$("$_bin" --version 2>/dev/null | head -1 || echo found)
  ok "codex CLI $_version"
}

_run_codex_cmd() {
  local _bin
  _bin=$(_codex_bin) || return 127
  "$_bin" "$@" 2>&1
}

_curl_marketplace_tarball() {
  local _dest="$1"
  local _url="https://github.com/${MARKETPLACE_REPO}/archive/refs/heads/main.tar.gz"
  log "Downloading marketplace via curl..."
  rm -rf "$_dest"
  mkdir -p "$_dest"
  if ! curl -fsSL "$_url" | tar xz --strip-components=1 -C "$_dest"; then
    warn "Failed to download marketplace tarball."
    return 1
  fi
  ok "Marketplace downloaded to $_dest"
}

ensure_codex_marketplace() {
  log "Registering Kestral marketplace..."
  local _output _rc
  set +e
  _output="$(_run_codex_cmd plugin marketplace add "$MARKETPLACE_REPO")"
  _rc=$?
  set -e
  verbose "codex marketplace add output: $_output (rc=$_rc)"

  if [ "$_rc" -eq 0 ]; then
    if printf '%s' "$_output" | grep -qi 'already'; then
      log "Already registered — upgrading..."
      set +e
      _output="$(_run_codex_cmd plugin marketplace upgrade "$MARKETPLACE_NAME")"
      _rc=$?
      set -e
      verbose "codex marketplace upgrade output: $_output (rc=$_rc)"
      if [ "$_rc" -ne 0 ]; then
        warn "Marketplace upgrade failed — using existing snapshot."
        verbose "upgrade failure: $_output"
      fi
    fi
    ok "Kestral marketplace registered"
    return 0
  fi

  verbose "marketplace add failed: $_output"
  warn "Trying tarball fallback..."

  if ! _curl_marketplace_tarball "$CODEX_LOCAL_MARKETPLACE_DIR"; then
    return 1
  fi

  set +e
  _output="$(_run_codex_cmd plugin marketplace add "$CODEX_LOCAL_MARKETPLACE_DIR")"
  _rc=$?
  set -e
  verbose "codex local marketplace add output: $_output (rc=$_rc)"

  if [ "$_rc" -eq 0 ]; then
    ok "Kestral marketplace registered from tarball"
    return 0
  fi

  verbose "local marketplace add failure: $_output"
  warn "Failed to register Kestral marketplace."
  return 1
}

install_or_update_codex_plugin() {
  log "Installing Kestral plugin..."
  local _output _rc
  set +e
  _output="$(_run_codex_cmd plugin add "$PLUGIN_ID")"
  _rc=$?
  set -e
  verbose "codex plugin add output: $_output (rc=$_rc)"

  if [ "$_rc" -eq 0 ]; then
    ok "Kestral plugin installed"
    return 0
  fi

  if printf '%s' "$_output" | grep -qi 'already installed'; then
    ok "Kestral plugin is up to date"
    return 0
  fi

  verbose "codex plugin add failure: $_output"
  warn "Failed to install Kestral plugin."
  return 1
}

print_codex_success() {
  printf '\nCodex: Kestral plugin is ready (connects to Kestral at %s).\n' "$REMOTE_MCP_URL"
  local _step=1
  if [ "$CODEX_REOPENED" -ne 1 ]; then
    printf '  %d. Fully quit and reopen Codex (required — running sessions won'\''t reload plugin content).\n' "$_step"
    _step=$((_step + 1))
  fi
  printf '  %d. Start a new thread (+ New thread — running threads never reload plugin content).\n' "$_step"
  _step=$((_step + 1))
  # shellcheck disable=SC2016
  printf '  %d. Type: $kestral-setup\n' "$_step"
}

install_to_codex() {
  warn_if_codex_running

  if ! ensure_codex_cli; then
    _finish_codex_restart
    return 1
  fi

  _restore_plugin_mcp_json_in_clone "$(_codex_marketplace_root 2>/dev/null || true)"
  if ! ensure_codex_marketplace; then
    _finish_codex_restart
    _print_codex_gui_fallback
    return 1
  fi

  local _codex_marketplace_root=""
  _codex_marketplace_root="$(_codex_marketplace_root 2>/dev/null || true)"

  if install_or_update_codex_plugin; then
    if [ -n "$_codex_marketplace_root" ]; then
      _rewrite_plugin_mcp_json_remote "$_codex_marketplace_root"
    fi
    _patch_all_installed_mcp_json
    _finish_codex_restart
    print_codex_success
    return 0
  fi

  _finish_codex_restart
  _print_codex_gui_fallback
  return 1
}

# --- Cursor path ---

_setup_script_plugin_root() {
  local _src _dir
  _src="${BASH_SOURCE[0]:-}"
  [ -n "$_src" ] || return 1
  _dir="$(cd "$(dirname "$_src")" && pwd)" || return 1
  if [ -f "${_dir}/.cursor-plugin/plugin.json" ]; then
    printf '%s' "$_dir"
    return 0
  fi
  return 1
}

_print_cursor_manual_fallback() {
  local _install_dir _local_root
  _install_dir="$(_cursor_plugin_install_dir)"
  _local_root="$(_setup_script_plugin_root 2>/dev/null || true)"

  printf '\nManual Cursor install:\n'

  if [ -n "$_local_root" ]; then
    _cmd_line "rm -rf ${_install_dir}"
    _cmd_line "mkdir -p ${_install_dir}"
    _cmd_line "cp -R ${_local_root}/. ${_install_dir}/"
  elif [ -d "${_install_dir}/.git" ]; then
    printf '  Plugin source already at %s — skip git clone.\n' "$_install_dir"
    _cmd_line "git -C ${_install_dir} pull --ff-only"
  else
    _cmd_line "mkdir -p $(dirname "${_install_dir}")"
    _cmd_line "git clone ${MARKETPLACE_GIT_URL} ${_install_dir}"
  fi
  printf '  Fully quit and restart Cursor.\n'
}

clone_or_update_cursor_plugin() {
  local _clone_dir
  _clone_dir="$(_cursor_plugin_install_dir)"
  mkdir -p "$(_cursor_plugins_local_dir)"

  if [ -d "$_clone_dir/.git" ]; then
    log "Updating Kestral plugin source for Cursor..."
    verbose "git pull --ff-only in $_clone_dir"
    _restore_plugin_mcp_json_in_clone "$_clone_dir"
    if ! git -C "$_clone_dir" diff --quiet 2>/dev/null || ! git -C "$_clone_dir" diff --cached --quiet 2>/dev/null; then
      warn "Plugin source has local modifications — can't update automatically."
      verbose "Dirty working tree in $_clone_dir"
      printf '  → Delete the folder and re-run, or use the manual steps below:\n' >&2
      verbose "Remedy: rm -rf \"$_clone_dir\" && re-run"
      _print_cursor_manual_fallback
      return 1
    fi
    if ! git -C "$_clone_dir" pull --ff-only >> "$LOGFILE" 2>&1; then
      warn "Couldn't update plugin source (history may have diverged)."
      verbose "git pull --ff-only failed in $_clone_dir"
      printf '  → Delete the folder and re-run, or use the manual steps below:\n' >&2
      _print_cursor_manual_fallback
      return 1
    fi
    ok "Kestral plugin source updated"
  elif [ -e "$_clone_dir" ]; then
    warn "Plugin source path exists but is not a git repository: $_clone_dir"
    printf '  → Remove it and re-run: rm -rf "%s"\n' "$_clone_dir" >&2
    _print_cursor_manual_fallback
    return 1
  else
    log "Downloading Kestral plugin source for Cursor..."
    verbose "git clone $MARKETPLACE_GIT_URL $_clone_dir"
    if ! git clone "$MARKETPLACE_GIT_URL" "$_clone_dir" >> "$LOGFILE" 2>&1; then
      warn "Failed to download plugin source."
      return 1
    fi
    ok "Kestral plugin source installed"
  fi

  _rewrite_plugin_mcp_json_remote "$_clone_dir"
}

_validate_cursor_plugin_source() {
  local _clone_dir="$1"
  if [ ! -f "${_clone_dir}/.cursor-plugin/plugin.json" ]; then
    warn "Cursor plugin manifest not found at ${_clone_dir}/.cursor-plugin/plugin.json"
    return 1
  fi
  return 0
}

_copy_cursor_local_plugin() {
  local _source="$1"
  local _dest
  _dest="$(_cursor_plugin_install_dir)"
  mkdir -p "$(_cursor_plugins_local_dir)"
  rm -rf "$_dest"
  mkdir -p "$_dest"

  if ! cp -R "${_source}/." "$_dest/"; then
    return 1
  fi
  ok "Installed Cursor plugin → $_dest"
}

print_cursor_success() {
  printf '\nCursor: Kestral plugin is ready (connects to Kestral at %s).\n' "$REMOTE_MCP_URL"
  printf '  1. Fully quit and restart Cursor (required — running sessions won'\''t reload plugin content).\n'
  printf '  2. Open Settings → Tools & MCPs. If Kestral shows Needs authentication, click Connect.\n'
  printf '  3. In agent chat, try "plan my day", "end of day review", or push a branch linked to a Kestral task.\n'
}

install_to_cursor() {
  local _plugin_root _local_root _install_dir
  _install_dir="$(_cursor_plugin_install_dir)"

  _local_root="$(_setup_script_plugin_root 2>/dev/null || true)"

  if [ -n "$_local_root" ]; then
    log "Installing local Kestral plugin source (${_local_root})"
    if ! _copy_cursor_local_plugin "$_local_root"; then
      _print_cursor_manual_fallback
      return 1
    fi
    _plugin_root="$_install_dir"
    _rewrite_plugin_mcp_json_remote "$_plugin_root"
  else
    if [ "$HAS_GIT" -eq 0 ]; then
      warn "Cursor plugin install requires git."
      _print_cursor_manual_fallback
      return 1
    fi

    if ! clone_or_update_cursor_plugin; then
      _print_cursor_manual_fallback
      return 1
    fi

    _plugin_root="$_install_dir"

    if ! _validate_cursor_plugin_source "$_plugin_root"; then
      _print_cursor_manual_fallback
      return 1
    fi
  fi

  print_cursor_success
  return 0
}

# --- Main target loop ---

_run_target() {
  local _target="$1"
  case "$_target" in
    claude-code)
      section "Installing Kestral to Claude Code"
      if install_to_claude_code; then
        TARGET_RESULT_CLAUDE="installed"
      else
        TARGET_RESULT_CLAUDE="FAILED"
      fi
      ;;
    claude-desktop)
      section "Installing Kestral to $(_desktop_app_name)"
      if install_to_claude_desktop; then
        TARGET_RESULT_DESKTOP="installed"
      else
        TARGET_RESULT_DESKTOP="FAILED"
      fi
      ;;
    codex)
      section "Installing Kestral to Codex"
      if install_to_codex; then
        TARGET_RESULT_CODEX="installed"
      else
        TARGET_RESULT_CODEX="FAILED"
      fi
      ;;
    cursor)
      section "Installing Kestral to Cursor"
      if install_to_cursor; then
        TARGET_RESULT_CURSOR="installed"
      else
        TARGET_RESULT_CURSOR="FAILED"
      fi
      ;;
    *)
      warn "Unknown target: $_target"
      ;;
  esac
}

_print_summary() {
  local _exit=0
  section "Done!"
  if [ -n "$TARGET_RESULT_CLAUDE" ]; then
    if [ "$TARGET_RESULT_CLAUDE" = "installed" ]; then
      ok "Claude Code: installed"
    else
      warn "Claude Code: failed — see errors above"
      _exit=1
    fi
  fi
  if [ -n "$TARGET_RESULT_DESKTOP" ]; then
    if [ "$TARGET_RESULT_DESKTOP" = "installed" ]; then
      ok "$(_desktop_app_name): installed"
    else
      warn "$(_desktop_app_name): failed — use the GUI steps printed above"
      _exit=1
    fi
  fi
  if [ -n "$TARGET_RESULT_CODEX" ]; then
    if [ "$TARGET_RESULT_CODEX" = "installed" ]; then
      ok "Codex: installed"
    else
      warn "Codex: failed — see instructions above"
      _exit=1
    fi
  fi
  if [ -n "$TARGET_RESULT_CURSOR" ]; then
    if [ "$TARGET_RESULT_CURSOR" = "installed" ]; then
      ok "Cursor: installed"
    else
      warn "Cursor: failed — see instructions above"
      _exit=1
    fi
  fi
  if [ "$_exit" -ne 0 ]; then
    printf '\n  Full logs: %s\n' "$LOGFILE"
  fi
  return "$_exit"
}

cleanup_old_local_mcp() {
  local _bin_dir="${HOME}/.kestral/bin"
  if [ -d "$_bin_dir" ]; then
    log "Removing old local helper (no longer needed — Kestral now connects directly)..."
    rm -rf "$_bin_dir"
    ok "Removed ${_bin_dir}"
  fi
}

# --- Full reinstall: remove all Kestral plugins, caches, and credentials ---

_rm_if_exists() {
  local _path="$1"
  if [ -e "$_path" ]; then
    rm -rf "$_path"
    ok "Removed $_path"
  fi
}

_strip_kestral_from_json() {
  local _file="$1"
  local _mode="$2"

  [ -f "$_file" ] || return 0
  grep -q -i kestral "$_file" 2>/dev/null || return 0
  [ -n "$RUBY_BIN" ] || return 1

  local _result
  _result="$("$RUBY_BIN" -e "$(cat <<'RUBY'
require 'json'
file = ARGV[0]
mode = ARGV[1]
data = JSON.parse(File.read(file))

case mode
when 'settings'
  if data['permissions'] && data['permissions']['allow']
    data['permissions']['allow'] = data['permissions']['allow'].reject { |p| p.downcase.include?('kestral') }
  end
  ['mcpServers', 'installedPlugins', 'enabledPlugins', 'extraKnownMarketplaces'].each do |key|
    next unless data[key].is_a?(Hash)
    data[key].reject! { |k, _| k.downcase.include?('kestral') }
  end
when 'known_marketplaces'
  data.reject! { |k, _| k.to_s.downcase.include?('kestral') }
when 'installed_plugins'
  if data['plugins'].is_a?(Hash)
    data['plugins'].reject! { |k, _| k.to_s.downcase.include?('kestral') }
  end
when 'claude_json'
  ['pluginUsage', 'mcpServers', 'enabledPlugins', 'installedPlugins', 'extraKnownMarketplaces'].each do |key|
    next unless data[key].is_a?(Hash)
    data[key].reject! { |k, _| k.to_s.downcase.include?('kestral') }
  end
when 'auth_cache'
  data.reject! do |k, _|
    key = k.to_s.downcase
    key.include?('kestral') || key.include?('app.kestral.ai') || key.include?('ai.kestral.app')
  end
end

print JSON.pretty_generate(data) + "\n"
RUBY
)" "$_file" "$_mode")" || return 1

  if [ -n "$_result" ]; then
    _json_write_atomic "$_file" "$_result"
    return 0
  fi
  return 1
}

_warn_kestral_manual_remote_mcp() {
  local _base _file

  for _base in \
    "$SESSIONS_BASE" \
    "${HOME}/Library/Application Support/Claude/claude-code-sessions"; do
    [ -d "$_base" ] || continue
    while IFS= read -r _file; do
      if grep -q 'app\.kestral\.ai/mcp' "$_file" 2>/dev/null; then
        warn "A manually added Kestral remote MCP connector may still appear in Claude Desktop."
        printf '  → Remove it in Claude Desktop: Customize → Connectors → Kestral → disconnect/remove.\n'
        printf '  → Per-task Cowork snapshots are left unchanged so prior task history is not rewritten.\n'
        return 0
      fi
    done < <(find "$_base" -mindepth 3 -maxdepth 3 -name 'local_*.json' 2>/dev/null)
  done
}

_clean_claude_desktop_configs() {
  local _path _file _base _cleaned=0

  if [ -d "$SESSIONS_BASE" ]; then
  while IFS= read -r _path; do
    rm -rf "$_path"
    verbose "Removed marketplace clone: $_path"
    _cleaned=1
  done < <(find "$SESSIONS_BASE" -path '*/cowork_plugins/marketplaces/kestral-plugins' -type d 2>/dev/null)

  while IFS= read -r _path; do
    rm -rf "$_path"
    verbose "Removed inline plugin data: $_path"
    _cleaned=1
  done < <(find "$SESSIONS_BASE" -path '*/.claude/plugins/data/kestral-*' -type d 2>/dev/null)

  while IFS= read -r _file; do
    if _strip_kestral_from_json "$_file" "known_marketplaces"; then
      verbose "Stripped Kestral from $_file"
      _cleaned=1
    fi
  done < <(find "$SESSIONS_BASE" -path '*/cowork_plugins/known_marketplaces.json' 2>/dev/null)

  while IFS= read -r _file; do
    if _strip_kestral_from_json "$_file" "installed_plugins"; then
      verbose "Stripped Kestral from $_file"
      _cleaned=1
    fi
  done < <(find "$SESSIONS_BASE" -path '*/cowork_plugins/installed_plugins.json' 2>/dev/null)

  while IFS= read -r _file; do
    if _strip_kestral_from_json "$_file" "settings"; then
      verbose "Stripped Kestral from $_file"
      _cleaned=1
    fi
  done < <(find "$SESSIONS_BASE" -path '*/cowork_settings.json' 2>/dev/null)

  while IFS= read -r _file; do
    if _strip_kestral_from_json "$_file" "claude_json"; then
      verbose "Stripped Kestral from $_file"
      _cleaned=1
    fi
  done < <(find "$SESSIONS_BASE" -path '*/.claude/.claude.json' 2>/dev/null)

  while IFS= read -r _file; do
    if _strip_kestral_from_json "$_file" "auth_cache"; then
      verbose "Stripped Kestral from $_file"
      _cleaned=1
    fi
  done < <(find "$SESSIONS_BASE" -path '*/.claude/mcp-needs-auth-cache.json' 2>/dev/null)

  while IFS= read -r _file; do
    rm -f "$_file"
    verbose "Removed Cowork MCP config: $_file"
    _cleaned=1
  done < <(find "$SESSIONS_BASE" \( -path '*kestral-plugins*' -o -path '*kestral@kestral-plugins*' \) -name '.mcp.json' 2>/dev/null)
  fi

  _warn_kestral_manual_remote_mcp

  if [ "$_cleaned" -eq 1 ]; then
    ok "Cleared Kestral from Claude Desktop Cowork configs"
  fi
}

_clean_claude_plugins() {
  section "Removing Kestral from Claude Code / Cowork"

  _rm_if_exists "${HOME}/.claude/plugins/cache/kestral-plugins"
  _rm_if_exists "${HOME}/.claude/plugins/marketplaces/kestral-plugins"
  _rm_if_exists "${HOME}/.claude/plugins/data/kestral-inline"
  _rm_if_exists "${HOME}/.claude/plugins/data/kestral-kestral-plugins"

  local _settings="${HOME}/.claude/settings.json"
  if [ -f "$_settings" ] && grep -q -i "kestral" "$_settings" 2>/dev/null; then
    if [ -n "$RUBY_BIN" ]; then
      if _strip_kestral_from_json "$_settings" "settings"; then
        ok "Removed Kestral entries from ${_settings}"
      fi
    else
      warn "Ruby not available — manually remove Kestral entries from ${_settings}"
    fi
  fi

  _clean_claude_code_auth_cache
  _clean_claude_desktop_configs
}

_clean_claude_code_auth_cache() {
  local _cache="${HOME}/.claude/mcp-needs-auth-cache.json"

  [ -f "$_cache" ] || return 0
  grep -q -i "kestral\|app\.kestral\.ai\|ai\.kestral\.app" "$_cache" 2>/dev/null || return 0
  [ -n "$RUBY_BIN" ] || return 0

  if _strip_kestral_from_json "$_cache" "auth_cache"; then
    ok "Removed Kestral entries from ${_cache}"
  fi
}

_clean_codex_plugins() {
  section "Removing Kestral from Codex"

  _rm_if_exists "${HOME}/.codex/plugins/cache/kestral-plugins"
  _rm_if_exists "${HOME}/.codex/.tmp/marketplaces/kestral-plugins"
  _rm_if_exists "${HOME}/.kestral/codex-marketplace"

  local _config="${HOME}/.codex/config.toml"
  if [ -f "$_config" ] && grep -q -i "kestral" "$_config" 2>/dev/null; then
    if [ -n "$RUBY_BIN" ]; then
      local _result
      _result="$("$RUBY_BIN" -e "$(cat <<'RUBY'
lines = File.readlines(ARGV[0])
output = []
skip = false
lines.each do |line|
  if line =~ /^\[.*kestral.*\]/i
    skip = true
    next
  end
  if skip
    if line =~ /^\[/
      skip = false
    else
      next
    end
  end
  output << line
end
# Remove trailing blank lines left by stripped sections
output.pop while output.last&.strip&.empty?
print output.join
RUBY
)" "$_config")" || true
      if [ -n "$_result" ]; then
        printf '%s\n' "$_result" > "$_config"
        ok "Stripped Kestral sections from ${_config}"
      fi
    else
      warn "Ruby not available — manually remove Kestral sections from ${_config}"
    fi
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    local _deleted=0
    while IFS= read -r _acct; do
      if security delete-generic-password -s "Codex MCP Credentials" -a "$_acct" 2>/dev/null; then
        _deleted=$((_deleted + 1))
      fi
    done < <(security dump-keychain 2>/dev/null | grep -A 5 "Codex MCP Credentials" | grep "acct" | grep -i "kestral" | sed 's/.*<blob>="//;s/"//' 2>/dev/null || true)
    if [ "$_deleted" -gt 0 ]; then
      ok "Removed ${_deleted} Kestral credential(s) from macOS Keychain"
    fi
  fi
}

_clean_cursor_plugins() {
  section "Removing Kestral from Cursor"

  _rm_if_exists "${HOME}/.cursor/plugins/local/${CURSOR_PLUGIN_LOCAL_NAME}"
  _rm_if_exists "${HOME}/.cursor/plugins/cache/kestral-plugins"
  _rm_if_exists "${HOME}/.kestral/cursor-marketplace"

  local _mkt_dir="${HOME}/.cursor/plugins/marketplaces/github.com/kestral-team/kestral-plugins"
  _rm_if_exists "$_mkt_dir"
  local _mkt_parent="${HOME}/.cursor/plugins/marketplaces/github.com/kestral-team"
  if [ -d "$_mkt_parent" ] && [ -z "$(ls -A "$_mkt_parent" 2>/dev/null)" ]; then
    rmdir "$_mkt_parent" 2>/dev/null || true
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    local _oauth_dir="${HOME}/Library/Application Support/Cursor/User/globalStorage/mcp-oauth-attempts"
    local _oauth_dir2="${HOME}/Library/Application Support/Cursor/User/globalStorage/anysphere.cursor-mcp/mcp-oauth-attempts"
    local _f _dir
    for _dir in "$_oauth_dir" "$_oauth_dir2"; do
      if [ -d "$_dir" ]; then
        while IFS= read -r _f; do
          rm -f "$_f"
          verbose "Removed OAuth attempt: $_f"
        done < <(grep -rl -i "kestral" "$_dir" 2>/dev/null || true)
      fi
    done
    ok "Cleared Kestral OAuth credentials from Cursor"
  fi
}

_clean_local_mcp_tokens() {
  section "Removing local MCP auth tokens"

  _rm_if_exists "${HOME}/.config/kestral"
  _rm_if_exists "${HOME}/.kestral/bin"
}

_full_reinstall_clean() {
  section "Full reinstall: removing all Kestral plugins, caches, and credentials"

  local _answer=""
  if read_tty "  This will remove all Kestral plugin data and credentials. Continue? [Y/n] " _answer; then
    case "$_answer" in
      [nN] | [nN][oO])
        abort "Full reinstall cancelled."
        ;;
    esac
  fi

  ensure_ruby 2>/dev/null || true

  _clean_local_mcp_tokens
  _clean_claude_plugins
  _clean_codex_plugins
  _clean_cursor_plugins

  ok "All Kestral plugin data removed. Proceeding with fresh install..."
}

main() {
  parse_args "$@"

  if [ "$FULL_REINSTALL" -eq 1 ]; then
    _full_reinstall_clean
  fi

  section "Checking prerequisites (git)"
  ensure_git

  cleanup_old_local_mcp

  section "Detecting installed apps"
  detect_apps

  section "Choosing install targets"
  select_targets

  local _target
  if [ "${#SELECTED_TARGETS[@]}" -gt 0 ]; then
    for _target in "${SELECTED_TARGETS[@]}"; do
      _run_target "$_target" || true
    done
  fi

  _print_summary
}

main "$@"
