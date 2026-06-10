#!/usr/bin/env bash
# Kestral plugin one-shot macOS setup script.
#
# Installs the Kestral plugin to Claude Code and/or Claude Desktop.

set -euo pipefail

MARKETPLACE_NAME="kestral-plugins"
MARKETPLACE_REPO="Kestral-Team/kestral-plugins"
MARKETPLACE_GIT_URL="https://github.com/${MARKETPLACE_REPO}.git"
PLUGIN_ID="kestral@${MARKETPLACE_NAME}"
CLAUDE_APP="/Applications/Claude.app"
SESSIONS_BASE="${HOME}/Library/Application Support/Claude/local-agent-mode-sessions"
MIN_NODE_MAJOR=20

# --- Parsed flags ---
APP_FLAG=""
DESKTOP_ROOT_FLAG=""
EXPLICIT_APP_FLAG=0

# --- Detection / selection state ---
HAS_CLAUDE_CLI=0
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

DESKTOP_SELECTED_ROOT=""
DESKTOP_BACKUP_SUFFIX=""

# --- Logfile ---

LOGFILE="${HOME}/.kestral/setup.log"
mkdir -p "${HOME}/.kestral"
: > "$LOGFILE"

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

# --- Usage ---

usage() {
  cat <<EOF
Kestral plugin setup (macOS)

Usage:
  curl -fsSL https://raw.githubusercontent.com/Kestral-Team/kestral-plugins/main/setup.sh | bash
  bash setup.sh [--app claude-code|claude-desktop|claude-code,claude-desktop] [--desktop-root <accountId>/<orgId>]

Options:
  --app <targets>       Non-interactive target set (comma-separated: claude-code, claude-desktop)
  --desktop-root <id>   Select Desktop session root when multiple exist
  -h, --help            Show this help

Examples:
  bash setup.sh --app claude-code
  bash setup.sh --app claude-desktop --desktop-root abc123/def456
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

# --- Prerequisites ---

require_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    abort_with_hint "This script supports macOS only." \
      "Use the manual install steps in https://github.com/Kestral-Team/kestral-plugins#install"
  fi
}

_ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    return 0
  fi
  log "Xcode Command Line Tools are required for git."
  if [ -r /dev/tty ]; then
    printf 'Opening the Apple installer — re-run this script after it finishes.\n' >/dev/tty
  fi
  xcode-select --install || true
  abort_with_hint "Waiting for Xcode Command Line Tools." \
    "Complete the Apple installer, then re-run this script."
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    ok "git $(git --version | awk '{print $3}')"
    return 0
  fi

  log "git not found — installing..."
  if command -v brew >/dev/null 2>&1; then
    brew install git
    ok "git installed via Homebrew"
    return 0
  fi

  _ensure_xcode_clt
  if command -v git >/dev/null 2>&1; then
    ok "git available after CLT install prompt"
    return 0
  fi

  abort_with_hint "git is required but not installed." \
    "Install Xcode Command Line Tools (xcode-select --install) or Homebrew (https://brew.sh), then re-run."
}

_node_major_version() {
  node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1
}

_ensure_node_via_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    return 1
  fi
  local _answer=""
  if read_tty "Install Node.js via Homebrew? [Y/n] " _answer; then
    case "$_answer" in
      [nN] | [nN][oO])
        return 1
        ;;
    esac
    log "Installing node via Homebrew..."
    brew install node
    return 0
  fi
  return 1
}

_ensure_node_upgrade_via_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    return 1
  fi
  local _answer=""
  if read_tty "Upgrade Node.js via Homebrew? [Y/n] " _answer; then
    case "$_answer" in
      [nN] | [nN][oO])
        return 1
        ;;
    esac
    log "Upgrading node via Homebrew..."
    brew upgrade node || brew install node
    return 0
  fi
  return 1
}

_print_node_install_instructions() {
  cat <<EOF
Node.js ${MIN_NODE_MAJOR}+ is required (Desktop install uses node for JSON merges; the plugin needs npx).

Install options:
  • Download LTS from https://nodejs.org
  • Homebrew: /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" then brew install node
  • Upgrade (Mac): npm install -g n && n lts

After installing Node, fully quit and reopen your Claude app. If Cowork still can't find node, restart your Mac
so /opt/homebrew/bin is on the GUI login PATH.
EOF
}

ensure_node() {
  if ! command -v node >/dev/null 2>&1; then
    log "Node.js not found."
    if _ensure_node_via_brew; then
      :
    else
      _print_node_install_instructions
      abort "Node.js is required."
    fi
  fi

  local _major
  _major="$(_node_major_version)"
  if [ -z "$_major" ] || [ "$_major" -lt "$MIN_NODE_MAJOR" ]; then
    log "Node.js v${_major:-?} is below required v${MIN_NODE_MAJOR}+."
    if _ensure_node_upgrade_via_brew; then
      _major="$(_node_major_version)"
    else
      _print_node_install_instructions
      abort "Node.js ${MIN_NODE_MAJOR}+ is required."
    fi
  fi

  if [ "$_major" -lt "$MIN_NODE_MAJOR" ]; then
    _print_node_install_instructions
    abort "Node.js ${MIN_NODE_MAJOR}+ is required (found v${_major})."
  fi

  ok "Node.js $(node --version)"
}

# --- App detection ---

_is_valid_desktop_org_root() {
  local _org_path="$1"
  [ -f "${_org_path}/cowork_settings.json" ] || [ -d "${_org_path}/cowork_plugins" ]
}

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
      if _is_valid_desktop_org_root "$_org_path"; then
        _mtime=0
        if [ -d "${_org_path}/cowork_plugins" ]; then
          _mtime="$(stat -f '%m' "${_org_path}/cowork_plugins" 2>/dev/null || echo 0)"
        elif [ -f "${_org_path}/cowork_settings.json" ]; then
          _mtime="$(stat -f '%m' "${_org_path}/cowork_settings.json" 2>/dev/null || echo 0)"
        fi
        DESKTOP_ROOTS+=("${_acc_name}/$(basename "$_org")")
        DESKTOP_ROOT_MTIMES+=("$_mtime")
      fi
    done
  done
}

detect_apps() {
  HAS_CLAUDE_CLI=0
  HAS_DESKTOP_APP=0
  HAS_DESKTOP_READY=0
  DESKTOP_NOT_READY=0

  if command -v claude >/dev/null 2>&1; then
    HAS_CLAUDE_CLI=1
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
  if [ "$HAS_CLAUDE_CLI" -eq 0 ] && [ "$HAS_DESKTOP_APP" -eq 0 ]; then
    printf '  (none — install Claude Code or Claude Desktop first)\n'
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
        abort_with_hint "Codex setup is not supported yet." \
          "Follow the Codex manual steps in https://github.com/Kestral-Team/kestral-plugins#codex-app"
        ;;
      *)
        abort "Unknown --app target: $_part (use claude-code, claude-desktop, or claude-code,claude-desktop)"
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
    abort_with_hint "No supported Claude apps detected." \
      "Install Claude Code (https://claude.ai/code) or Claude Desktop (https://claude.ai/download), then re-run."
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
  _prompt="${_prompt}— Enter = all, or type numbers (e.g. \"1\"): "

  if read_tty "$_prompt" _choice; then
    _choice="$(printf '%s' "$_choice" | tr -d '[:space:]')"
    if [ -z "$_choice" ]; then
      SELECTED_TARGETS=("${DETECTED_TARGETS[@]}")
    else
      local _digit
      for _digit in $(printf '%s' "$_choice" | grep -o '[12]' || true); do
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
  cat <<EOF

Claude Code: Kestral plugin is ready.
  1. Run: claude
  2. In chat: /kestral:kestral-setup
EOF
}

install_to_claude_code() {
  if ! ensure_claude_cli; then
    return 1
  fi

  if ! ensure_marketplace; then
    return 1
  fi
  if ! install_or_update_plugin; then
    return 1
  fi
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

warn_if_desktop_running() {
  if pgrep -x Claude >/dev/null 2>&1; then
    local _answer=""
    if read_tty "  Claude Desktop is running. Quit it now? [Y/n] " _answer; then
      case "$_answer" in
        [nN] | [nN][oO])
          warn "Proceeding while Claude Desktop is running — you must fully quit and reopen after install."
          return 0
          ;;
      esac
      log "Quitting Claude Desktop..."
      osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
      local _wait=0
      while pgrep -x Claude >/dev/null 2>&1; do
        sleep 1
        _wait=$((_wait + 1))
        if [ "$_wait" -ge 10 ]; then
          warn "Claude Desktop didn't quit in time — proceeding anyway."
          return 0
        fi
      done
      ok "Claude Desktop quit"
    else
      warn "Claude Desktop is running — you'll need to quit and reopen it after install."
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
}

_register_marketplace() {
  local _plugins_dir _known _clone_dir _iso
  _plugins_dir="$(_desktop_cowork_plugins_dir)"
  _known="${_plugins_dir}/known_marketplaces.json"
  _clone_dir="$(_desktop_marketplace_clone_dir)"
  mkdir -p "$_plugins_dir"
  _backup_json_if_exists "$_known"

  _iso="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"

  node -e "
const fs = require('fs');
const file = process.argv[1];
const cloneDir = process.argv[2];
const name = process.argv[3];
const repo = process.argv[4];
const iso = process.argv[5];
let data = {};
if (fs.existsSync(file)) {
  data = JSON.parse(fs.readFileSync(file, 'utf8'));
}
data[name] = {
  source: { source: 'github', repo },
  installLocation: cloneDir,
  lastUpdated: iso,
};
const tmp = file + '.tmp.' + process.pid;
fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n');
fs.renameSync(tmp, file);
" "$_known" "$_clone_dir" "$MARKETPLACE_NAME" "$MARKETPLACE_REPO" "$_iso" || return 1
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

  node -e "
const fs = require('fs');
const path = require('path');
const file = process.argv[1];
const cloneDir = process.argv[2];
const pluginId = process.argv[3];
const iso = process.argv[4];
const sha = process.argv[5];
const manifestPath = path.join(cloneDir, '.claude-plugin', 'plugin.json');
const version = JSON.parse(fs.readFileSync(manifestPath, 'utf8')).version;

function convertV1ToV2(data) {
  if (data.version === 2) return data;
  const plugins = {};
  for (const [id, entry] of Object.entries(data.plugins || {})) {
    if (Array.isArray(entry)) {
      plugins[id] = entry;
    } else {
      plugins[id] = [entry];
    }
  }
  return { version: 2, plugins };
}

let data = { version: 2, plugins: {} };
if (fs.existsSync(file)) {
  data = convertV1ToV2(JSON.parse(fs.readFileSync(file, 'utf8')));
}
const entry = {
  scope: 'user',
  installPath: cloneDir,
  version,
  installedAt: iso,
  lastUpdated: iso,
  gitCommitSha: sha,
  auto: false,
};
const existing = data.plugins[pluginId];
if (existing && Array.isArray(existing)) {
  const idx = existing.findIndex(e => e.scope === 'user');
  if (idx >= 0) {
    existing[idx] = { ...existing[idx], ...entry, installedAt: existing[idx].installedAt || iso };
  } else {
    existing.push(entry);
  }
  data.plugins[pluginId] = existing;
} else {
  data.plugins[pluginId] = [entry];
}
const tmp = file + '.tmp.' + process.pid;
fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n');
fs.renameSync(tmp, file);
" "$_installed" "$_clone_dir" "$PLUGIN_ID" "$_iso" "$_sha" || return 1
  verbose "Wrote installed_plugins.json (schema v2)"
}

_enable_plugin() {
  local _settings
  _settings="$(_desktop_org_dir)/cowork_settings.json"
  _backup_json_if_exists "$_settings"

  node -e "
const fs = require('fs');
const file = process.argv[1];
const pluginId = process.argv[2];
const marketplaceName = process.argv[3];
const repo = process.argv[4];
const cloneDir = process.argv[5];
const iso = process.argv[6];
let data = { enabledPlugins: {} };
if (fs.existsSync(file)) {
  data = JSON.parse(fs.readFileSync(file, 'utf8'));
}
if (!data.enabledPlugins) data.enabledPlugins = {};
data.enabledPlugins[pluginId] = true;
if (!data.extraKnownMarketplaces) data.extraKnownMarketplaces = {};
if (!data.extraKnownMarketplaces[marketplaceName]) {
  data.extraKnownMarketplaces[marketplaceName] = {
    source: { source: 'github', repo, name: marketplaceName },
    installLocation: cloneDir,
    lastUpdated: iso,
  };
}
const tmp = file + '.tmp.' + process.pid;
fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n');
fs.renameSync(tmp, file);
" "$_settings" "$PLUGIN_ID" "$MARKETPLACE_NAME" "$MARKETPLACE_REPO" "$(_desktop_marketplace_clone_dir)" "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")" || return 1
  verbose "Enabled plugin in cowork_settings.json"
}

print_desktop_success() {
  cat <<EOF

Claude Desktop: Kestral plugin files are installed.
  1. Fully quit and reopen Claude Desktop (required — running sessions won't see disk edits).
  2. Start a new task (+ New task — running tasks never reload plugin content).
  3. In Cowork, run: /kestral:kestral-setup

If Node was just installed, fully quit and reopen Claude Desktop (or restart your Mac) so Node is on the GUI login PATH.
EOF
}

install_to_claude_desktop() {
  DESKTOP_BACKUP_SUFFIX=".kestral-backup-$(date +%s)"

  select_desktop_root || return 1
  warn_if_desktop_running

  if ! clone_or_update_marketplace; then
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

  print_desktop_success
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
      abort "Codex setup is not supported yet."
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
  if [ "$_exit" -ne 0 ]; then
    printf '\n  Full logs: %s\n' "$LOGFILE"
  fi
  return "$_exit"
}

main() {
  parse_args "$@"
  require_macos

  section "Checking prerequisites (git, Node.js 20+)"
  ensure_git
  ensure_node

  section "Detecting installed Claude apps"
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
