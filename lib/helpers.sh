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

sr_install_nerd_font() {
  local os font_name
  os="$(uname -s 2>/dev/null || echo Unknown)"
  font_name="font-meslo-lg-nerd-font"

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
    printf "ℹ️  On Linux, install a Nerd Font (e.g., MesloLGS) via your package manager.\n"
  fi
}

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
  local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
  if [ ! -f "$plist" ]; then
    printf "ℹ️  iTerm2 preferences not found; launch iTerm2 once, then re-run Terminal & UX domain\n"
    return 0
  fi
  defaults write com.googlecode.iterm2 "Normal Font" -string "MesloLGS Nerd Font 14"
  defaults write com.googlecode.iterm2 "Non Ascii Font" -string "MesloLGS Nerd Font 14"
  printf "✅ iTerm2 configured to use MesloLGS Nerd Font (size 14)\n"
  printf "💡 Restart iTerm2 to apply font changes to existing sessions.\n"
}

# -----------------------------
# Version state (JSON) helpers
# -----------------------------
SR_STATE_DIR="${SR_STATE_DIR:-$PWD/state}"
SR_VERSION_STATE="${SR_VERSION_STATE:-$SR_STATE_DIR/.base.version.state.json}"

sr_version_state_init() {
  mkdir -p "$SR_STATE_DIR"
  if [ ! -f "$SR_VERSION_STATE" ]; then
    printf "{}\n" > "$SR_VERSION_STATE"
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    if ! jq empty "$SR_VERSION_STATE" >/dev/null 2>&1; then
      cp "$SR_VERSION_STATE" "$SR_VERSION_STATE.bak.$(date +%Y%m%d-%H%M%S)"
      printf "{}\n" > "$SR_VERSION_STATE"
    fi
  fi
}

sr_version_state_read() {
  local tool="$1" field="$2"
  command -v jq >/dev/null 2>&1 || return 0
  jq -r --arg t "$tool" --arg f "$field" '.[$t][$f] // empty' "$SR_VERSION_STATE"
}

# Write/update a tool entry (without domains)
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
     '
     .[$t] = (.[$t] // {})
     | .[$t].installed = $i
     | .[$t].version = $v
     | .[$t].source = $s
     | .[$t].last_checked = $ts
     ' \
     "$SR_VERSION_STATE" > "$tmp" && mv "$tmp" "$SR_VERSION_STATE"
}

# Add a domain tag into tool.domains (unique)
sr_state_add_domain() {
  local tool="$1" domain="$2"
  command -v jq >/dev/null 2>&1 || return 0
  [ -z "$domain" ] && return 0
  local tmp; tmp="$(mktemp)"
  jq --arg t "$tool" --arg d "$domain" '
    .[$t] = (.[$t] // {})
    | .[$t].domains = ((.[$t].domains // []) + [$d] | unique)
  ' "$SR_VERSION_STATE" > "$tmp" && mv "$tmp" "$SR_VERSION_STATE"
}

# ---- Brew + generic version discovery (non-fatal) ----

sr_brew_installed_version() {
  local name="$1"
  command -v brew >/dev/null 2>&1 || return 0
  command -v jq   >/dev/null 2>&1 || return 0
  brew info --json=v2 "$name" 2>/dev/null \
    | jq -r '.formulae[0].installed[0].version // empty' \
    || true
}

# NEW: cask version
sr_brew_installed_cask_version() {
  local name="$1"
  command -v brew >/dev/null 2>&1 || return 0
  command -v jq   >/dev/null 2>&1 || return 0

  brew info --cask --json=v2 "$name" 2>/dev/null \
    | jq -r '
      .casks[0] as $c
      | (
          # installed can be array, string, null, or missing
          ( $c.installed
            | if type=="array" and length>0 then .[0].version
              elif type=="string" then .
              else empty
              end
          )
          // $c.version
          // empty
        )
    ' 2>/dev/null || true
}

sr_brew_latest_stable_version() {
  local name="$1"
  command -v brew >/dev/null 2>&1 || return 0
  command -v jq   >/dev/null 2>&1 || return 0
  brew info --json=v2 "$name" 2>/dev/null \
    | jq -r '.formulae[0].versions.stable // empty' \
    || true
}

# Tool-aware version detection
sr_cmd_version() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || return 0

  case "$cmd" in
    kubectl)
      if command -v jq >/dev/null 2>&1; then
        kubectl version -o json 2>/dev/null \
          | jq -r '.clientVersion.gitVersion // empty' \
          | sed -e 's/^v//' \
          | head -n1 && return 0
      fi
      kubectl version --client --short 2>/dev/null \
        | grep -Eo 'v[0-9]+(\.[0-9]+){1,2}' \
        | sed -e 's/^v//' \
        | head -n1 || true
      return 0
      ;;
    helm)
      helm version --short 2>/dev/null \
        | grep -Eo 'v?[0-9]+(\.[0-9]+){1,2}' \
        | sed -e 's/^v//' \
        | head -n1 || true
      return 0
      ;;
    parallel)
      local line
      line="$(parallel --version 2>/dev/null | head -n1)"
      printf "%s\n" "$line" \
        | grep -Eo '([0-9]{8}|[0-9]+(\.[0-9]+){1,2})' \
        | head -n1 || true
      return 0
      ;;
    tmux)
      tmux -V 2>/dev/null \
        | grep -Eo '[0-9]+(\.[0-9]+){1,2}[a-z]?' \
        | head -n1 || true
      return 0
      ;;
    jq)
      jq --version 2>/dev/null \
        | grep -Eo '[0-9]+(\.[0-9]+){1,2}' \
        | head -n1 || true
      return 0
      ;;
  esac

  "$cmd" --version 2>&1 \
    | grep -Eo '[0-9]+(\.[0-9]+){1,3}' \
    | head -n1 || true
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

# Resolve the likely source of a tool for state recording (brew|webi|path)
sr_detect_source() {
  local tool="$1" brew_name="$2" install_kind="$3"
  if [ "$install_kind" = "webi" ]; then
    printf "webi\n"; return
  fi
  if command -v brew >/dev/null 2>&1; then
    # consider casks too
    if [ "$install_kind" = "cask" ] || brew list --cask >/dev/null 2>&1 && brew list --cask | grep -qx "${brew_name:-$tool}"; then
      printf "brew\n"; return
    fi
    if brew list --formula >/dev/null 2>&1 && brew list --formula | grep -qx "${brew_name:-$tool}"; then
      printf "brew\n"; return
    fi
  fi
  printf "path\n"
}

# Binary name candidates for tools whose CLI != formula name (or meta tools)
sr_binary_candidates() {
  case "$1" in
    ripgrep) echo "rg ripgrep" ;;
    rg)      echo "rg ripgrep" ;;
    git-delta|delta) echo "delta" ;;
    docker-compose|compose) echo "docker-compose 'docker compose'" ;;
    gh-key-upload|gh) echo "gh" ;;
    openssh) echo "ssh scp sftp ssh-add" ;;
    powerlevel10k) echo "" ;;
    kubectx) echo "kubectx" ;;
    kubens)  echo "kubens" ;;
    bottom)  echo "btm bottom" ;;
    btm)     echo "btm bottom" ;;
    # GUI casks typically have no CLI on PATH by default
    raycast) echo "" ;;
    visual-studio-code|vscode) echo "code" ;;
    *) echo "$1" ;;
  esac
}

sr_any_cmd_exists() {
  local cand
  for cand in "$@"; do
    [ -z "$cand" ] && continue
    if [[ "$cand" == *" "* ]]; then
      local first="${cand%% *}" second="${cand#* }"
      command -v "$first" >/dev/null 2>&1 && "$first" "$second" --help >/dev/null 2>&1 && return 0
    else
      command -v "$cand" >/dev/null 2>&1 && return 0
    fi
  done
  return 1
}

# Record version/state (now handles casks properly)
# Args: tool brew_name install_kind [domain]
sr_record_tool_version() {
  local tool="$1" brew_name="$2" install_kind="$3" domain="${4:-}"
  sr_version_state_init

  local source; source="$(sr_detect_source "$tool" "$brew_name" "$install_kind")"
  local version="" installed=false

  # Handle casks (GUI apps) first
  if [ "$install_kind" = "cask" ]; then
    if command -v brew >/dev/null 2>&1 && brew list --cask >/dev/null 2>&1 && brew list --cask | grep -qx "${brew_name:-$tool}"; then
      installed=true
      version="$(sr_brew_installed_cask_version "${brew_name:-$tool}")"
    fi
    sr_version_state_write "$tool" "$installed" "${version:-}" "${source:-path}"
    [ -n "$domain" ] && sr_state_add_domain "$tool" "$domain"
    return 0
  fi

  # Special-case meta/tools
  if [ "$tool" = "powerlevel10k" ]; then
    local omz_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local p10k_dir="$omz_custom/themes/powerlevel10k"
    if [ "$source" = "brew" ] || [ -d "$p10k_dir" ]; then
      installed=true
      version="$(sr_brew_installed_version "$brew_name")"
    fi
    sr_version_state_write "$tool" "$installed" "${version:-}" "${source:-path}"
    [ -n "$domain" ] && sr_state_add_domain "$tool" "$domain"
    return 0
  fi

  if [ "$tool" = "openssh" ]; then
    if [ "$source" = "brew" ] || sr_any_cmd_exists ssh; then
      installed=true
      version="$(sr_brew_installed_version "$brew_name")"
      [ -z "$version" ] && version="$(sr_cmd_version ssh)"
    fi
    sr_version_state_write "$tool" "$installed" "${version:-}" "${source:-path}"
    [ -n "$domain" ] && sr_state_add_domain "$tool" "$domain"
    return 0
  fi

  # Formulae & generic
  local cands; cands=($(sr_binary_candidates "$tool"))
  [ "${#cands[@]}" -eq 0 ] && cands=("$tool")

  if sr_any_cmd_exists "${cands[@]}"; then
    installed=true
    if [ "$source" = "brew" ] && [ -n "$brew_name" ]; then
      version="$(sr_brew_installed_version "$brew_name")"
    fi
    if [ -z "$version" ]; then
      for cand in "${cands[@]}"; do
        [[ "$cand" == *" "* ]] && continue
        version="$(sr_cmd_version "$cand")"
        [ -n "$version" ] && break
      done
    fi
  else
    installed=false
  fi

  sr_version_state_write "$tool" "$installed" "${version:-}" "${source:-path}"
  [ -n "$domain" ] && sr_state_add_domain "$tool" "$domain"
}

# If SR_UPGRADE=1 and brew shows a newer stable, upgrade.
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
