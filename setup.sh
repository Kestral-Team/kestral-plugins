#!/usr/bin/env bash
# Kestral plugin one-shot macOS setup script.
#
# Installs the Kestral plugin to Claude Code, Claude Desktop, and/or Codex.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
#   bash setup.sh [--app claude-code|claude-desktop|codex] [--desktop-root <accountId>/<orgId>] [--remote-mcp]
#
# Options:
#   --app <targets>       Non-interactive target set (comma-separated: claude-code, claude-desktop, codex)
#   --desktop-root <id>   Select Desktop session root when multiple exist
#   --remote-mcp          Use Kestral's hosted MCP endpoint (only git required; no local process)
#   -h, --help            Show this help
#
# Examples:
#   bash setup.sh --app claude-code
#   bash setup.sh --app codex
#   curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --remote-mcp

set -euo pipefail

MARKETPLACE_NAME="kestral-plugins"
MARKETPLACE_REPO="Kestral-Team/kestral-plugins"
MARKETPLACE_GIT_URL="https://github.com/${MARKETPLACE_REPO}.git"
PLUGIN_ID="kestral@${MARKETPLACE_NAME}"
CODEX_APP="/Applications/Codex.app"
CODEX_LOCAL_MARKETPLACE_DIR="${HOME}/.kestral/codex-marketplace"
CLAUDE_APP="/Applications/Claude.app"
SESSIONS_BASE="${HOME}/Library/Application Support/Claude/local-agent-mode-sessions"
KESTRAL_MCP_SERVER_NAME="Kestral"
KESTRAL_MCP_PLUGIN_BIN_REL="bin/kestral-mcp"
KESTRAL_MCP_BIN_DIR="${HOME}/.kestral/bin"
KESTRAL_MCP_BIN="${KESTRAL_MCP_BIN_DIR}/kestral-mcp"
GO_MCP_BINARY_INSTALLED=0
RUBY_BIN=""

# --- Parsed flags ---
APP_FLAG=""
DESKTOP_ROOT_FLAG=""
EXPLICIT_APP_FLAG=0
USE_REMOTE_MCP=0

# --- Detection / selection state ---
HAS_GIT=0
HAS_CLAUDE_CLI=0
HAS_CODEX_CLI=0
HAS_DESKTOP_APP=0
HAS_DESKTOP_READY=0
DESKTOP_NOT_READY=0

# bash 3.2-safe indexed arrays (no associative arrays)
DETECTED_TARGETS=()
SELECTED_TARGETS=()
DESKTOP_ROOTS=()
DESKTOP_ROOT_MTIMES=()

TARGET_RESULT_CLAUDE=""
TARGET_RESULT_DESKTOP=""
TARGET_RESULT_CODEX=""

DESKTOP_SELECTED_ROOT=""
DESKTOP_BACKUP_SUFFIX=""
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
Kestral plugin setup (macOS)

Usage:
  curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
  bash setup.sh [--app claude-code|claude-desktop|codex] [--desktop-root <accountId>/<orgId>] [--remote-mcp]

Options:
  --app <targets>       Non-interactive target set (comma-separated: claude-code, claude-desktop, codex)
  --desktop-root <id>   Select Desktop session root when multiple exist
  --remote-mcp          Use Kestral's hosted MCP endpoint (only git required; no local process)
  -h, --help            Show this help

Examples:
  bash setup.sh --app claude-code
  bash setup.sh --app codex
  bash setup.sh --app claude-code,codex
  bash setup.sh --app claude-desktop --desktop-root abc123/def456
  curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash -s -- --remote-mcp
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
      --desktop-root)
        shift
        DESKTOP_ROOT_FLAG="${1:-}"
        [ -n "$DESKTOP_ROOT_FLAG" ] || abort "--desktop-root requires a value"
        ;;
      --remote-mcp)
        USE_REMOTE_MCP=1
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

require_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    abort_with_hint "This script supports macOS only." \
      "Use the manual install steps in https://github.com/Kestral-Team/kestral-plugins#install"
  fi
}

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

_install_go_mcp_binary_from_path() {
  local _source="$1"
  mkdir -p "$KESTRAL_MCP_BIN_DIR"
  install -m 755 "$_source" "$KESTRAL_MCP_BIN"
}

install_go_mcp_binary_from_plugin_root() {
  local _plugin_root="${1:-}"
  local _release_label _zip_url _sums_url _tmp_dir

  if [ -n "$_plugin_root" ] && [ -x "${_plugin_root}/${KESTRAL_MCP_PLUGIN_BIN_REL}" ]; then
    _install_go_mcp_binary_from_path "${_plugin_root}/${KESTRAL_MCP_PLUGIN_BIN_REL}"
    ok "Installed kestral-mcp from plugin → $KESTRAL_MCP_BIN"
    return 0
  fi

  _release_label="latest"
  _zip_url="https://github.com/${MARKETPLACE_REPO}/releases/latest/download/kestral-mcp-darwin-universal.zip"
  _sums_url="https://github.com/${MARKETPLACE_REPO}/releases/latest/download/SHA256SUMS"

  mkdir -p "$KESTRAL_MCP_BIN_DIR"
  _tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/kestral-mcp-install.XXXXXX")"

  log "Downloading Kestral helper from ${MARKETPLACE_REPO} (${_release_label})..."
  if ! curl -fsSL "$_zip_url" -o "${_tmp_dir}/kestral-mcp-darwin-universal.zip"; then
    rm -rf "$_tmp_dir"
    abort_with_hint "Failed to download the Kestral helper." \
      "Check https://github.com/${MARKETPLACE_REPO}/releases includes kestral-mcp-darwin-universal.zip on the latest release."
  fi

  if curl -fsSL "$_sums_url" -o "${_tmp_dir}/SHA256SUMS" 2>/dev/null; then
    (
      cd "$_tmp_dir" || exit 1
      shasum -a 256 -c SHA256SUMS
    ) || {
      rm -rf "$_tmp_dir"
      abort "Checksum verification failed for the Kestral helper."
    }
    verbose "Verified SHA256 checksum for kestral-mcp-darwin-universal.zip"
  else
    warn "SHA256SUMS not found for ${_release_label} — skipping checksum verification."
  fi

  unzip -q -o "${_tmp_dir}/kestral-mcp-darwin-universal.zip" -d "$_tmp_dir"
  if [ ! -f "${_tmp_dir}/kestral-mcp" ]; then
    rm -rf "$_tmp_dir"
    abort "Downloaded archive did not contain kestral-mcp."
  fi

  _install_go_mcp_binary_from_path "${_tmp_dir}/kestral-mcp"
  rm -rf "$_tmp_dir"
  ok "Installed kestral-mcp (${_release_label}) → $KESTRAL_MCP_BIN"
}

ensure_go_mcp_binary_installed() {
  local _plugin_root="${1:-}"
  if [ "$GO_MCP_BINARY_INSTALLED" -eq 1 ]; then
    return 0
  fi
  install_go_mcp_binary_from_plugin_root "$_plugin_root"
  GO_MCP_BINARY_INSTALLED=1
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

# Restore .mcp.json in a marketplace clone before git pull so the working tree is clean.
# The file is rewritten again after the update.
_restore_plugin_mcp_json_in_clone() {
  local _clone_root="${1:-}"
  if [ -n "$_clone_root" ] && [ -d "${_clone_root}/.git" ]; then
    git -C "$_clone_root" checkout -- .mcp.json 2>/dev/null || true
  fi
}

_rewrite_plugin_mcp_json() {
  local _plugin_root="$1"
  local _mcp_file="${_plugin_root}/.mcp.json"
  if [ ! -f "$_mcp_file" ]; then
    return 0
  fi

  local _result
  _result="$("$RUBY_BIN" -e "$(cat <<'RUBY'
require 'json'
file = ARGV[0]
cmd = ARGV[1]
name = ARGV[2]
data = JSON.parse(File.read(file))
if data.key?('mcpServers')
  data['mcpServers'] = {} unless data['mcpServers'].is_a?(Hash)
  data['mcpServers'][name] = { 'command' => cmd, 'args' => [] }
end
if data.key?('mcp_servers')
  data['mcp_servers'] = {} unless data['mcp_servers'].is_a?(Hash)
  data['mcp_servers'][name] = { 'command' => cmd, 'args' => [] }
end
print JSON.pretty_generate(data) + "\n"
RUBY
)" "$_mcp_file" "$KESTRAL_MCP_BIN" "$KESTRAL_MCP_SERVER_NAME")" || return 1
  _json_write_atomic "$_mcp_file" "$_result"
  verbose "Rewrote ${_mcp_file} → ${KESTRAL_MCP_BIN}"
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
  local _mcp_file="${_plugin_root}/.mcp.json"
  if [ ! -f "$_mcp_file" ]; then
    return 0
  fi
  local _content
  _content=$(printf '%s\n' "{
  \"mcpServers\": {
    \"Kestral\": {
      \"url\": \"${REMOTE_MCP_URL}\"
    }
  },
  \"mcp_servers\": {
    \"Kestral\": {
      \"url\": \"${REMOTE_MCP_URL}\"
    }
  }
}")
  _json_write_atomic "$_mcp_file" "$_content"
  verbose "Rewrote ${_mcp_file} → ${REMOTE_MCP_URL}"
}

_mcp_rewrite_fn() {
  if [ "$USE_REMOTE_MCP" -eq 1 ]; then
    printf '_rewrite_plugin_mcp_json_remote'
  else
    printf '_rewrite_plugin_mcp_json'
  fi
}

_patch_all_installed_mcp_json() {
  local _fn
  _fn="$(_mcp_rewrite_fn)"
  _patch_kestral_mcp_json_under "${HOME}/.claude" "$_fn"
  _patch_kestral_mcp_json_under "${HOME}/.codex" "$_fn"
  _patch_kestral_mcp_json_under "${HOME}/.kestral" "$_fn"
  if [ -d "$SESSIONS_BASE" ]; then
    _patch_kestral_mcp_json_under "$SESSIONS_BASE" "$_fn"
  fi
}

# --- App detection ---

_enumerate_desktop_roots() {
  DESKTOP_ROOTS=()
  DESKTOP_ROOT_MTIMES=()

  if [ ! -d "$SESSIONS_BASE" ]; then
    return 0
  fi

  local _account _org _org_path _mtime _acc_name
  for _account in "$SESSIONS_BASE"/*; do
    [ -d "$_account" ] || continue
    _acc_name="$(basename "$_account")"
    if [ "$_acc_name" = "skills-plugin" ]; then
      continue
    fi
    for _org in "$_account"/*; do
      [ -d "$_org" ] || continue
      _org_path="$_org"
      _mtime=0
      if [ -d "${_org_path}/cowork_plugins" ]; then
        _mtime="$(stat -f '%m' "${_org_path}/cowork_plugins" 2>/dev/null || echo 0)"
      elif [ -f "${_org_path}/cowork_settings.json" ]; then
        _mtime="$(stat -f '%m' "${_org_path}/cowork_settings.json" 2>/dev/null || echo 0)"
      else
        _mtime="$(stat -f '%m' "${_org_path}" 2>/dev/null || echo 0)"
      fi
      DESKTOP_ROOTS+=("${_acc_name}/$(basename "$_org")")
      DESKTOP_ROOT_MTIMES+=("$_mtime")
    done
  done
}

detect_apps() {
  HAS_CLAUDE_CLI=0
  HAS_CODEX_CLI=0
  HAS_DESKTOP_APP=0
  HAS_DESKTOP_READY=0
  DESKTOP_NOT_READY=0

  if command -v claude >/dev/null 2>&1; then
    HAS_CLAUDE_CLI=1
  fi

  if _codex_bin >/dev/null; then
    HAS_CODEX_CLI=1
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

_print_detection_summary() {
  if [ "$HAS_CLAUDE_CLI" -eq 1 ]; then
    printf '    [1] Claude Code (claude CLI found)\n'
  fi
  if [ "$HAS_DESKTOP_READY" -eq 1 ]; then
    printf '    [2] Claude Desktop (signed in, %s session root(s))\n' "${#DESKTOP_ROOTS[@]}"
  elif [ "$DESKTOP_NOT_READY" -eq 1 ]; then
    printf '    [ ] Claude Desktop (installed but not signed in — open it, sign in, re-run)\n'
  fi
  if [ "$HAS_CODEX_CLI" -eq 1 ]; then
    printf '    [3] Codex (codex CLI found)\n'
  fi
  if [ "$HAS_CLAUDE_CLI" -eq 0 ] && [ "$HAS_DESKTOP_APP" -eq 0 ] && [ "$HAS_CODEX_CLI" -eq 0 ]; then
    printf '  (none detected)\n'
  fi
}

_add_target_if_missing() {
  local _t="$1"
  local _existing
  for _existing in "${SELECTED_TARGETS[@]:-}"; do
    if [ "$_existing" = "$_t" ]; then
      return 0
    fi
  done
  SELECTED_TARGETS+=("$_t")
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
      claude-desktop)
        _add_target_if_missing "claude-desktop"
        ;;
      codex)
        _add_target_if_missing "codex"
        ;;
      *)
        abort "Unknown --app target: $_part (use claude-code, claude-desktop, or codex)"
        ;;
    esac
  done
}

select_targets() {
  DETECTED_TARGETS=()
  SELECTED_TARGETS=()

  if [ "$HAS_CLAUDE_CLI" -eq 1 ]; then
    DETECTED_TARGETS+=("claude-code")
  fi
  if [ "$HAS_DESKTOP_READY" -eq 1 ]; then
    DETECTED_TARGETS+=("claude-desktop")
  fi
  if [ "$HAS_CODEX_CLI" -eq 1 ]; then
    DETECTED_TARGETS+=("codex")
  fi

  _print_detection_summary

  if [ "$EXPLICIT_APP_FLAG" -eq 1 ]; then
    _parse_app_flag "$APP_FLAG"
    local _t
    for _t in "${SELECTED_TARGETS[@]}"; do
      if [ "$_t" = "claude-code" ] && [ "$HAS_CLAUDE_CLI" -eq 0 ]; then
        : # ensure_claude_cli handles --app claude-code with missing CLI
      elif [ "$_t" = "claude-desktop" ]; then
        if [ "$HAS_DESKTOP_APP" -eq 0 ]; then
          abort_with_hint "Claude Desktop is not installed." \
            "Install Claude Desktop from https://claude.ai/download, sign in, then re-run."
        fi
        if [ "$HAS_DESKTOP_READY" -eq 0 ]; then
          abort_with_hint "Claude Desktop is installed but no Cowork session was found." \
            "Open Claude Desktop, sign in, then re-run this script."
        fi
      fi
    done
    return 0
  fi

  if [ "${#DETECTED_TARGETS[@]}" -eq 0 ]; then
    abort_with_hint "No supported apps detected." \
      "Install Claude Code (https://claude.ai/code), Claude Desktop (https://claude.ai/download), or Codex (https://codex.openai.com), then re-run."
  fi

  # Default: all detected targets pre-selected
  local _choice=""
  local _prompt="Install Kestral to: "
  if [ "$HAS_CLAUDE_CLI" -eq 1 ]; then
    _prompt="${_prompt}[1] Claude Code  "
  fi
  if [ "$HAS_DESKTOP_READY" -eq 1 ]; then
    _prompt="${_prompt}[2] Claude Desktop  "
  fi
  if [ "$HAS_CODEX_CLI" -eq 1 ]; then
    _prompt="${_prompt}[3] Codex  "
  fi
  _prompt="${_prompt}— Enter = all, or type numbers (e.g. \"1\"): "

  if read_tty "$_prompt" _choice; then
    _choice="$(printf '%s' "$_choice" | tr -d '[:space:]')"
    if [ -z "$_choice" ]; then
      SELECTED_TARGETS=("${DETECTED_TARGETS[@]}")
    else
      local _digit
      for _digit in $(printf '%s' "$_choice" | grep -o '[123]' || true); do
        case "$_digit" in
          1)
            if [ "$HAS_CLAUDE_CLI" -eq 1 ]; then
              _add_target_if_missing "claude-code"
            fi
            ;;
          2)
            if [ "$HAS_DESKTOP_READY" -eq 1 ]; then
              _add_target_if_missing "claude-desktop"
            fi
            ;;
          3)
            if [ "$HAS_CODEX_CLI" -eq 1 ]; then
              _add_target_if_missing "codex"
            fi
            ;;
        esac
      done
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

print_claude_success() {
  if [ "$USE_REMOTE_MCP" -eq 1 ]; then
    cat <<EOF

Claude Code: Kestral plugin is ready (connects to Kestral at ${REMOTE_MCP_URL}).
  1. Fully quit and reopen Claude Code if it was running (required — running sessions won't reload plugin content).
  2. Run: claude
  3. In chat: /kestral:kestral-setup
EOF
    return 0
  fi

  cat <<EOF

Claude Code: Kestral plugin is ready.
  1. Fully quit and reopen Claude Code if it was running (required — running sessions won't reload plugin content).
  2. Run: claude
  3. In chat: /kestral:kestral-setup
EOF
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
  if [ "$USE_REMOTE_MCP" -ne 1 ]; then
    local _marketplace_root=""
    _marketplace_root="$(_claude_marketplace_root 2>/dev/null || true)"
    ensure_go_mcp_binary_installed "$_marketplace_root"
  fi
  if ! install_or_update_plugin; then
    return 1
  fi
  _patch_all_installed_mcp_json
  print_claude_success
}

# --- Claude Desktop path ---

_print_desktop_gui_fallback() {
  cat <<'EOF'

Claude Desktop manual install (GUI fallback):
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

_sort_desktop_roots_by_mtime() {
  local _i _j _tmp_root _tmp_mtime _max_idx
  local _len="${#DESKTOP_ROOTS[@]}"
  _i=0
  while [ "$_i" -lt "$_len" ]; do
    _max_idx="$_i"
    _j=$((_i + 1))
    while [ "$_j" -lt "$_len" ]; do
      if [ "${DESKTOP_ROOT_MTIMES[$_j]}" -gt "${DESKTOP_ROOT_MTIMES[$_max_idx]}" ]; then
        _max_idx="$_j"
      fi
      _j=$((_j + 1))
    done
    if [ "$_max_idx" -ne "$_i" ]; then
      _tmp_root="${DESKTOP_ROOTS[_i]}"
      DESKTOP_ROOTS[_i]="${DESKTOP_ROOTS[_max_idx]}"
      DESKTOP_ROOTS[_max_idx]="$_tmp_root"
      _tmp_mtime="${DESKTOP_ROOT_MTIMES[_i]}"
      DESKTOP_ROOT_MTIMES[_i]="${DESKTOP_ROOT_MTIMES[_max_idx]}"
      DESKTOP_ROOT_MTIMES[_max_idx]="$_tmp_mtime"
    fi
    _i=$((_i + 1))
  done
}

select_desktop_root() {
  _sort_desktop_roots_by_mtime

  if [ -n "$DESKTOP_ROOT_FLAG" ]; then
    local _r
    for _r in "${DESKTOP_ROOTS[@]}"; do
      if [ "$_r" = "$DESKTOP_ROOT_FLAG" ]; then
        DESKTOP_SELECTED_ROOT="$DESKTOP_ROOT_FLAG"
        verbose "Selected account: $DESKTOP_SELECTED_ROOT"
        return 0
      fi
    done
    warn "Account not found: $DESKTOP_ROOT_FLAG"
    printf '  → Available accounts: %s — re-run with --desktop-root <id>\n' "$(printf '%s\n' "${DESKTOP_ROOTS[@]}")" >&2
    return 1
  fi

  if [ "${#DESKTOP_ROOTS[@]}" -eq 1 ]; then
    DESKTOP_SELECTED_ROOT="${DESKTOP_ROOTS[0]}"
    verbose "Auto-selected account: $DESKTOP_SELECTED_ROOT"
    return 0
  fi

  log "Multiple logged-in accounts found:"
  local _idx=1
  local _i=0
  while [ "$_i" -lt "${#DESKTOP_ROOTS[@]}" ]; do
    local _hint=""
    if [ "$_i" -eq 0 ]; then
      _hint=" (most recent)"
    fi
    printf '    [%s] %s%s\n' "$_idx" "${DESKTOP_ROOTS[$_i]}" "$_hint"
    _idx=$((_idx + 1))
    _i=$((_i + 1))
  done

  local _choice=""
  if read_tty "  Which account? [1]: " _choice; then
    _choice="${_choice:-1}"
    if ! printf '%s' "$_choice" | grep -qE '^[0-9]+$'; then
      warn "Invalid selection."
      return 1
    fi
    _i=$((_choice - 1))
    if [ "$_i" -lt 0 ] || [ "$_i" -ge "${#DESKTOP_ROOTS[@]}" ]; then
      warn "Invalid selection."
      return 1
    fi
    DESKTOP_SELECTED_ROOT="${DESKTOP_ROOTS[$_i]}"
    verbose "Selected account: $DESKTOP_SELECTED_ROOT"
    return 0
  fi

  warn "Multiple accounts found — couldn't prompt for selection."
  printf '  → Available accounts:\n' >&2
  _i=0
  while [ "$_i" -lt "${#DESKTOP_ROOTS[@]}" ]; do
    printf '    - %s\n' "${DESKTOP_ROOTS[$_i]}" >&2
    _i=$((_i + 1))
  done
  printf '  → Re-run with: --desktop-root %s\n' "$(printf '%s' "${DESKTOP_ROOTS[0]}")" >&2
  return 1
}

_reopen_claude_desktop() {
  if [ ! -d "$CLAUDE_APP" ]; then
    warn "Claude Desktop not found at $CLAUDE_APP — open it manually after install."
    return 1
  fi
  log "Reopening Claude Desktop..."
  if open "$CLAUDE_APP" >> "$LOGFILE" 2>&1; then
    DESKTOP_REOPENED=1
    ok "Claude Desktop reopened"
    return 0
  fi
  warn "Couldn't reopen Claude Desktop automatically — open it manually."
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
    local _answer=""
    if read_tty "  Claude Desktop is running. Restart now to load the Kestral plugin? [Y/n] " _answer; then
      case "$_answer" in
        [nN] | [nN][oO])
          warn "Proceeding while Claude Desktop is running — restart after install to load the Kestral plugin."
          return 0
          ;;
      esac
      log "Restarting Claude Desktop..."
      osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
      local _wait=0
      while pgrep -x Claude >/dev/null 2>&1; do
        sleep 1
        _wait=$((_wait + 1))
        if [ "$_wait" -ge 10 ]; then
          warn "Claude Desktop didn't stop in time — proceeding anyway."
          return 0
        fi
      done
      DESKTOP_RESTART_PENDING=1
      ok "Claude Desktop stopped — will reopen after install completes."
    else
      warn "Claude Desktop is running — restart after install to load the Kestral plugin."
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

_desktop_install_failed() {
  warn "Desktop install failed — restoring previous state..."
  verbose "Restoring JSON backups (suffix: $DESKTOP_BACKUP_SUFFIX)"
  _restore_desktop_backups
  _finish_desktop_restart
  printf '  → Logs: %s\n' "$LOGFILE" >&2
  _print_desktop_gui_fallback
  return 1
}

clone_or_update_marketplace() {
  local _clone_dir
  _clone_dir="$(_desktop_marketplace_clone_dir)"
  mkdir -p "$(dirname "$_clone_dir")"

  if [ -d "$_clone_dir/.git" ]; then
    log "Updating Kestral marketplace..."
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
    ok "Kestral marketplace updated"
  else
    log "Installing Kestral marketplace..."
    verbose "git clone $MARKETPLACE_GIT_URL $_clone_dir"
    if ! git clone "$MARKETPLACE_GIT_URL" "$_clone_dir" >> "$LOGFILE" 2>&1; then
      warn "Failed to download marketplace."
      return 1
    fi
    ok "Kestral marketplace installed"
  fi

  if [ "$USE_REMOTE_MCP" -eq 1 ]; then
    _rewrite_plugin_mcp_json_remote "$(_desktop_marketplace_clone_dir)"
  else
    ensure_go_mcp_binary_installed "$(_desktop_marketplace_clone_dir)"
    _rewrite_plugin_mcp_json "$(_desktop_marketplace_clone_dir)"
  fi
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

print_desktop_success() {
  local _detail=""
  if [ "$USE_REMOTE_MCP" -eq 1 ]; then
    _detail=" (connects to Kestral at ${REMOTE_MCP_URL})"
  else
    _detail=" (helper at ${KESTRAL_MCP_BIN})"
  fi

  printf '\nClaude Desktop: Kestral plugin files are installed%s.\n' "$_detail"
  local _step=1
  if [ "$DESKTOP_REOPENED" -ne 1 ]; then
    printf '  %d. Fully quit and reopen Claude Desktop (required — running sessions won'\''t see disk edits).\n' "$_step"
    _step=$((_step + 1))
  fi
  printf '  %d. Start a new task (+ New task — running tasks never reload plugin content).\n' "$_step"
  _step=$((_step + 1))
  printf '  %d. In Cowork, run: /kestral:kestral-setup\n' "$_step"
}

install_to_claude_desktop() {
  if [ "$HAS_GIT" -eq 0 ]; then
    warn "Claude Desktop requires git. Install via: xcode-select --install or brew install git"
    _print_desktop_gui_fallback
    return 1
  fi

  if [ "$USE_REMOTE_MCP" -eq 1 ] && ! ensure_ruby; then
    _print_desktop_gui_fallback
    return 1
  fi

  DESKTOP_BACKUP_SUFFIX=".kestral-backup-$(date +%s)"

  select_desktop_root || return 1
  warn_if_desktop_running

  if ! clone_or_update_marketplace; then
    _finish_desktop_restart
    return 1
  fi

  log "Configuring plugin..."
  if ! _register_marketplace; then
    _desktop_install_failed
    return 1
  fi
  if ! _write_installed_plugin; then
    _desktop_install_failed
    return 1
  fi
  if ! _enable_plugin; then
    _desktop_install_failed
    return 1
  fi
  ok "Plugin configured and enabled"

  local _dir _org_dir
  _dir="$(_desktop_cowork_plugins_dir)"
  _org_dir="$(_desktop_org_dir)"
  rm -f "${_dir}/known_marketplaces.json${DESKTOP_BACKUP_SUFFIX}" \
        "${_dir}/installed_plugins.json${DESKTOP_BACKUP_SUFFIX}" \
        "${_org_dir}/cowork_settings.json${DESKTOP_BACKUP_SUFFIX}" 2>/dev/null || true

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
  local _detail=""
  if [ "$USE_REMOTE_MCP" -eq 1 ]; then
    _detail=" (connects to Kestral at ${REMOTE_MCP_URL})"
  fi

  printf '\nCodex: Kestral plugin is ready%s.\n' "$_detail"
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
  if [ "$USE_REMOTE_MCP" -ne 1 ]; then
    ensure_go_mcp_binary_installed "$_codex_marketplace_root"
  fi

  if install_or_update_codex_plugin; then
    if [ -n "$_codex_marketplace_root" ]; then
      "$(_mcp_rewrite_fn)" "$_codex_marketplace_root"
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
      section "Installing Kestral to Claude Desktop"
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
      ok "Claude Desktop: installed"
    else
      warn "Claude Desktop: failed — use the GUI steps printed above"
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
  if [ "$_exit" -ne 0 ]; then
    printf '\n  Full logs: %s\n' "$LOGFILE"
  fi
  return "$_exit"
}

main() {
  parse_args "$@"
  require_macos

  if [ "$USE_REMOTE_MCP" -eq 1 ]; then
    section "Checking prerequisites (git)"
    ensure_git
  else
    section "Checking prerequisites (git, Ruby)"
    ensure_git
    ensure_ruby
  fi

  section "Detecting installed apps"
  detect_apps

  section "Choosing install targets"
  select_targets

  local _target
  for _target in "${SELECTED_TARGETS[@]}"; do
    _run_target "$_target" || true
  done

  _print_summary
}

main "$@"
