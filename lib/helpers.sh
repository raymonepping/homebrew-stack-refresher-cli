#!/usr/bin/env bash
set -euo pipefail

# Utility: run a domain function if it exists, otherwise warn
sr_run_or_warn() {
  local fn="$1"; shift || true
  if command -v "$fn" >/dev/null 2>&1; then
    "$fn" "$@"
  else
    printf "⚠️  %s not implemented yet\n" "$fn"
  fi
}

# Optional: tiny helper used elsewhere if needed
sr_fn_exists() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------
# Nerd Font install + iTerm2 font configuration
# ---------------------------------------------

# Idempotently install Meslo Nerd Font via Homebrew (macOS).
# On Linux or if Homebrew missing, we simply no-op with a hint.
sr_install_nerd_font() {
  local os font_name
  os="$(uname -s 2>/dev/null || echo Unknown)"
  font_name="font-meslo-lg-nerd-font"

  # If the font is already available in user's fonts, skip (best-effort).
  # This won't cover all cases, but avoids re-install spam.
  if fc-list 2>/dev/null | grep -qi 'MesloLGS Nerd Font'; then
    printf "✅ Nerd Font (MesloLGS) already available on system\n"
    return 0
  fi

  if [ "$os" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
      if brew list --cask "$font_name" >/dev/null 2>&1; then
        printf "✅ Nerd Font (%s) already installed\n" "$font_name"
      else
        printf "⬇️  Installing Nerd Font (%s)\n" "$font_name"
        brew install --cask "$font_name"
      fi
    else
      printf "⚠️  Homebrew not found; skipping Nerd Font install\n"
    fi
  else
    # Non-macOS: leave a helpful hint; do not fail the run.
    printf "ℹ️  On Linux, install a Nerd Font (e.g., MesloLGS) via your package manager.\n"
  fi
}

# Idempotently set iTerm2 to use Meslo Nerd Font (macOS only).
# Uses macOS 'defaults' to set the font for new profiles (not retroactive to all existing custom profiles).
sr_set_iterm2_font() {
  local os
  os="$(uname -s 2>/dev/null || echo Unknown)"
  if [ "$os" != "Darwin" ]; then
    printf "ℹ️  iTerm2 font wiring skipped (non-macOS)\n"
    return 0
  fi

  if ! command -v defaults >/dev/null 2>&1; then
    printf "⚠️  macOS 'defaults' tool not available; cannot configure iTerm2 font\n"
    return 0
  fi

  # If iTerm2 prefs file isn’t present yet (first run), skip quietly.
  local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
  if [ ! -f "$plist" ]; then
    printf "ℹ️  iTerm2 preferences not found; launch iTerm2 once, then re-run Terminal & UX domain\n"
    return 0
  fi

  # Set fonts for new profiles (Normal & Non-ASCII). Size 14 is a sensible default.
  defaults write com.googlecode.iterm2 "Normal Font" -string "MesloLGS Nerd Font 14"
  defaults write com.googlecode.iterm2 "Non Ascii Font" -string "MesloLGS Nerd Font 14"

  printf "✅ iTerm2 configured to use MesloLGS Nerd Font (size 14)\n"
  printf "💡 Restart iTerm2 to apply font changes to existing sessions.\n"
}

# -----------------------------
# Version state (JSON) helpers
# -----------------------------
# State file lives in ./state/.base.version.state.json by default.
SR_STATE_DIR="${SR_STATE_DIR:-$PWD/state}"
SR_VERSION_STATE="${SR_VERSION_STATE:-$SR_STATE_DIR/.base.version.state.json}"

# Ensure state file exists and is valid JSON.
sr_version_state_init() {
  mkdir -p "$SR_STATE_DIR"
  if [ ! -f "$SR_VERSION_STATE" ]; then
    printf "{}\n" > "$SR_VERSION_STATE"
    return 0
  fi
  # best-effort validation
  if command -v jq >/dev/null 2>&1; then
    if ! jq empty "$SR_VERSION_STATE" >/dev/null 2>&1; then
      cp "$SR_VERSION_STATE" "$SR_VERSION_STATE.bak.$(date +%Y%m%d-%H%M%S)"
      printf "{}\n" > "$SR_VERSION_STATE"
    fi
  fi
}

# Read a field from state: .[tool].field
sr_version_state_read() {
  local tool="$1" field="$2"
  command -v jq >/dev/null 2>&1 || return 0
  jq -r --arg t "$tool" --arg f "$field" '.[$t][$f] // empty' "$SR_VERSION_STATE"
}

# Write/update a tool entry
# Args: tool installed(true/false) version source
sr_version_state_write() {
  local tool="$1" installed="$2" version="$3" source="$4"
  command -v jq >/dev/null 2>&1 || return 0
  local tmp; tmp="$(mktemp)"
  local ts; ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq --arg t "$tool" \
     --argjson i "$installed" \
     --arg v "$version" \
     --arg s "$source" \
     --arg ts "$ts" \
     '.[$t] = {installed: $i, version: $v, source: $s, last_checked: $ts}' \
     "$SR_VERSION_STATE" > "$tmp" && mv "$tmp" "$SR_VERSION_STATE"
}

# Best-effort: get installed version of a brew formula (by name)
sr_brew_installed_version() {
  local name="$1"
  command -v brew >/dev/null 2>&1 || return 0
  command -v jq   >/dev/null 2>&1 || return 0
  # Do not exit on brew/jq failure under pipefail
  brew info --json=v2 "$name" 2>/dev/null \
    | jq -r '.formulae[0].installed[0].version // empty' \
    || true
}

# Best-effort: get latest stable version known to brew
sr_brew_latest_stable_version() {
  local name="$1"
  command -v brew >/dev/null 2>&1 || return 0
  command -v jq   >/dev/null 2>&1 || return 0
  brew info --json=v2 "$name" 2>/dev/null \
    | jq -r '.formulae[0].versions.stable // empty' \
    || true
}

# Fallback: try "<cmd> --version" and scrape a semver looking string.
sr_cmd_version() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || return 0
  # Don’t let a “no match” kill the script under pipefail
  "$cmd" --version 2>&1 \
    | grep -Eo '[0-9]+(\.[0-9]+){1,3}' \
    | head -n1 \
    || true
}

# Compare two versions using sort -V.
# returns 0 if equal, 1 if a>b, 2 if a<b
sr_semver_cmp() {
  local a="$1" b="$2"
  [ -z "$a" ] && [ -z "$b" ] && return 0
  [ -z "$a" ] && return 2
  [ -z "$b" ] && return 1
  if [ "$a" = "$b" ]; then return 0; fi
  if printf "%s\n%s\n" "$a" "$b" | sort -V | head -n1 | grep -qx "$b"; then
    return 1  # a > b
  else
    return 2  # a < b
  fi
}

# Resolve the likely source of a tool for state recording
# brew|webi|path
sr_detect_source() {
  local tool="$1" brew_name="$2" install_kind="$3"
  if [ "$install_kind" = "webi" ]; then
    printf "webi\n"; return
  fi
  if command -v brew >/dev/null 2>&1 && brew list --formula >/dev/null 2>&1; then
    # if brew knows about this formula or it's installed via brew
    if brew list --formula | grep -qx "${brew_name:-$tool}"; then
      printf "brew\n"; return
    fi
  fi
  printf "path\n"
}

# After (or if) a tool is present, record version + source into state.
# Args: tool brew_name install_kind
sr_record_tool_version() {
  local tool="$1" brew_name="$2" install_kind="$3"
  sr_version_state_init

  local source; source="$(sr_detect_source "$tool" "$brew_name" "$install_kind")"
  local version=""

  if [ "$source" = "brew" ] && [ -n "$brew_name" ]; then
    version="$(sr_brew_installed_version "$brew_name")"
  fi
  if [ -z "$version" ]; then
    version="$(sr_cmd_version "$tool")"
  fi

  if command -v "$tool" >/dev/null 2>&1; then
    sr_version_state_write "$tool" true "${version:-unknown}" "$source"
  else
    sr_version_state_write "$tool" false "" "$source"
  fi
}

# If SR_UPGRADE=1 and brew shows a newer stable, upgrade.
# Prints a warning when outdated if not upgrading.
sr_brew_maybe_upgrade() {
  local brew_name="$1"
  command -v brew >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local installed latest
  installed="$(sr_brew_installed_version "$brew_name")"
  latest="$(sr_brew_latest_stable_version "$brew_name")"
  [ -z "$installed" ] && return 0
  [ -z "$latest" ] && return 0

  sr_semver_cmp "$installed" "$latest"
  case $? in
    2)
      # installed < latest
      if [ "${SR_UPGRADE:-0}" = "1" ]; then
        printf "⬆️  Upgrading %s (current: %s → latest: %s)\n" "$brew_name" "$installed" "$latest"
        brew upgrade "$brew_name" >/dev/null 2>&1 || true
        ok "$brew_name upgraded"
      else
        printf "⚠️  %s is outdated (current: %s, latest: %s). Set SR_UPGRADE=1 to auto-upgrade.\n" "$brew_name" "$installed" "$latest"
      fi
      ;;
    *) : ;;
  esac
}
