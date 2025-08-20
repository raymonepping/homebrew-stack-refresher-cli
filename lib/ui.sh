#!/usr/bin/env bash
set -euo pipefail

have(){ command -v "$1" >/dev/null 2>&1; }

# visuals to stderr so stdout can carry the return token
hr(){ printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '─' >&2; }
say(){ printf "%s\n" "$*" >&2; }
_trim(){ printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
_strip_ansi(){ sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'; }

: "${SR_ROOT:="$(cd "$(dirname "$0")/.." && pwd)"}"
: "${SR_CONF:="$SR_ROOT/configuration"}"
: "${SR_STATE:="$SR_ROOT/state"}"
: "${SR_VERSION_STATE:="$SR_STATE/.base.version.state.json"}"

# --- Domain metadata (icon + title) ------------------------------------------
_sr_domain_icon_title() {
  case "$1" in
    1)  printf "🖥️  Terminal & UX" ;;
    2)  printf "🔑 SSH & Key Management" ;;
    3)  printf "🧬 Git & Source Control" ;;
    4)  printf "⚙️  Code & Dev Tools" ;;
    5)  printf "🐳 Containers & Runtimes" ;;
    6)  printf "⎈ Kubernetes (Local Dev)" ;;
    7)  printf "🔐 Secrets & Certs" ;;
    8)  printf "📊 Observability & Logs" ;;
    9)  printf "🏗️  Infrastructure as Code" ;;
    10) printf "⏱️  Automation & Scheduling" ;;
    11) printf "🌟 Bonus Tools (CLI Suite)" ;;
  esac
}

_sr_domain_json() {
  case "$1" in
    1)  echo "$SR_CONF/domains/domain_01_terminal.json" ;;
    2)  echo "$SR_CONF/domains/domain_02_ssh.json" ;;
    3)  echo "$SR_CONF/domains/domain_03_git.json" ;;
    4)  echo "$SR_CONF/domains/domain_04_code.json" ;;
    5)  echo "$SR_CONF/domains/domain_05_containers.json" ;;
    6)  echo "$SR_CONF/domains/domain_06_k8s.json" ;;
    7)  echo "$SR_CONF/domains/domain_07_secrets.json" ;;
    8)  echo "$SR_CONF/domains/domain_08_observability.json" ;;
    9)  echo "$SR_CONF/domains/domain_09_iac.json" ;;
    10) echo "$SR_CONF/domains/domain_10_automation.json" ;;
    11) echo "" ;;
  esac
}

# Pull MUST tools from a domain json
_sr_domain_must_tools() {
  local json="$1"
  have jq && [ -f "$json" ] && jq -r '.tools.must[]?' "$json" 2>/dev/null || true
}

# Quick map of brew outdated (quiet list) -> newline-separated names
_sr_brew_outdated_list() {
  have brew || return 0
  brew outdated --quiet 2>/dev/null || true
}

# Status computation:
# - If no state/jq/json: 🕒 Pending
# - If any MUST tool outdated (brew): ⚠️ Needs Upgrade
# - If all MUST installed: ✅ Up to Date
# - Else: 🕒 Pending
_sr_domain_status_phrase() {
  local idx="$1"
  local json="$(_sr_domain_json "$idx")"

  # Bonus tools: mark Installed if we want (no strict rules). We'll show "✅ Installed".
  if [ "$idx" = "11" ]; then
    printf "✅ Installed"
    return
  fi

  if ! have jq || [ ! -s "$SR_VERSION_STATE" ] || [ ! -f "$json" ]; then
    printf "🕒 Pending"
    return
  fi

  # Gather MUST tools
  local tools; tools="$(_sr_domain_must_tools "$json")"
  if [ -z "$tools" ]; then
    printf "🕒 Pending"
    return
  fi

  # Check install coverage
  local total=0 okc=0
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    total=$((total+1))
    if jq -e --arg tool "$t" '.[ $tool ].installed == true' "$SR_VERSION_STATE" >/dev/null 2>&1; then
      okc=$((okc+1))
    fi
  done <<< "$tools"

  # If we can check outdated via brew, do it (best-effort)
  local needs_upgrade=0
  if have brew; then
    local outdated
    outdated="$(_sr_brew_outdated_list)"
    if [ -n "$outdated" ]; then
      # map each tool -> brew formula name via your mapper? Here we assume tool name equals formula most of the time.
      while IFS= read -r t; do
        [ -n "$t" ] || continue
        if printf '%s\n' "$outdated" | grep -qx "$t"; then
          needs_upgrade=1
          break
        fi
      done <<< "$tools"
    fi
  fi

  if [ "$needs_upgrade" -eq 1 ]; then
    printf "⚠️  Needs Upgrade"
  else
    if [ "$total" -gt 0 ] && [ "$okc" -eq "$total" ]; then
      printf "✅ Up to Date"
    else
      printf "🕒 Pending"
    fi
  fi
}

# Build formatted domain lines with padding aligned to your target layout
_sr_domain_line() {
  local idx="$1"
  local title icon_title status
  icon_title="$(_sr_domain_icon_title "$idx")"
  status="$(_sr_domain_status_phrase "$idx")"
  # Format: "  1. <icon+title>    <status>"
  # Keep columns tidy (title left 27–30 chars depending on icon width)
  printf " %2d. %-28s %s\n" "$idx" "$icon_title" "$status"
}

_sr_build_menu_items() {
  local i
  for i in {1..11}; do
    _sr_domain_line "$i"
  done
  echo " A. Install ALL MUST (all domains)"
  echo " Q. Quit"
}

# Map short key -> token
_sr_map_quick_choice() {
  local ans="$1"
  case "$ans" in
    1|2|3|4|5|6|7|8|9|10|11) echo "$ans" ;;
    A|a) echo "A" ;;
    Q|q) echo "Q" ;;
    *) echo "" ;;
  esac
}

# Main menu presenter: returns token (1..11 / A / Q) on stdout
sr_menu_main() {
  hr
  say "🛠️  DevOps Workstation Setup"
  hr
  say "📦 Domains Overview:"
  mapfile -t items < <(_sr_build_menu_items)
  for it in "${items[@]}"; do say "  $it"; done
  hr

  local picked="" ans=""
  if have gum; then
    # Quick key selection without echoing escape garbage
    say "Use ↑/↓ + Enter, or press [1–11/A/Q]…"
    IFS= read -r -n1 -s ans </dev/tty || ans=""
    case "$ans" in
      [1-9]) picked="$ans" ;;
      0) IFS= read -r -n1 -s ans2 </dev/tty || ans2=""; case "0$ans2" in 010) picked="10";; 011) picked="11";; esac ;;
      [AaQq]) picked="$(_sr_map_quick_choice "$ans")" ;;
      *) picked="$(printf '%s\n' "${items[@]}" | gum choose --header 'Select a domain or action')" || picked="";;
    esac
  elif have fzf; then
    picked="$(printf '%s\n' "${items[@]}" | fzf --prompt='Select > ' --height=80% --border)" || picked=""
  else
    say "Type 1–11 / A / Q and press Enter:"
    IFS= read -r ans || ans=""
    picked="$(_sr_map_quick_choice "$(_trim "$ans")")"
  fi

  # Normalize pick from a full line
  if [ -n "$picked" ] && [[ "$picked" != [0-9AQaq]* ]]; then
    picked="$(printf '%s' "$picked" | _strip_ansi | tr -d '\r' | _trim)"
    case "$picked" in
      [0-9]*.*) picked="${picked%%.*}";;    # "  1. …"
      A.*)      picked="A";;
      Q.*)      picked="Q";;
      *)        if [[ "$picked" =~ ^([0-9]+) ]]; then picked="${BASH_REMATCH[1]}"; fi ;;
    esac
  fi

  [ -n "${picked:-}" ] && printf '%s\n' "$picked" || printf ''
}

# Multi-select helper (not changed, but kept modern)
sr_select_multi() {
  local prompt="$1"; shift
  local items=("$@")
  local out=""
  if have gum; then
    out="$(printf '%s\n' "${items[@]}" | gum choose --no-limit --cursor='▶' --header "$prompt" || true)"
  elif have fzf; then
    out="$(printf '%s\n' "${items[@]}" | fzf --multi --prompt="$prompt > " --height=80% --border || true)"
  else
    say "$prompt"
    local i=1
    for it in "${items[@]}"; do say " [$i] $it"; i=$((i+1)); done
    say "Pick numbers (space-separated, Enter=none):"
    local picks=""; IFS= read -r picks || true
    local sel=()
    for n in $picks; do
      [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#items[@]}" && sel+=("${items[$((n-1))]}") ]
    done
    out="$(printf '%s\n' "${sel[@]:-}")"
  fi
  out="$(printf '%s\n' "$out" | _strip_ansi | tr -d '\r' | sed '/^$/d')"
  [ -n "$out" ] && printf '%s\n' "$out"
}

sr_confirm() {
  local msg="$1"
  if have gum; then gum confirm "$msg"; else
    say "$msg [y/N] "
    local a=""; IFS= read -r a || true
    [[ "$a" =~ ^[Yy]$ ]]
  fi
}
