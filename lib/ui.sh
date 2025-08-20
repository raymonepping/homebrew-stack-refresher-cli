#!/usr/bin/env bash
set -euo pipefail

have(){ command -v "$1" >/dev/null 2>&1; }

# --- everything visual -> stderr (so it won't get captured) ---
hr(){ printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '─' >&2; }
say(){ printf "%s\n" "$*" >&2; }
_trim(){ printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
_strip_ansi(){ sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'; }

# Resolve repo paths provided by launcher
: "${SR_ROOT:="$(cd "$(dirname "$0")/.." && pwd)"}"
: "${SR_CONF:="$SR_ROOT/configuration"}"
: "${SR_STATE:="$SR_ROOT/state"}"
: "${SR_VERSION_STATE:="$SR_STATE/.base.version.state.json"}"

# Map domain index -> title + JSON file
_sr_domain_title() {
  case "$1" in
    1)  echo "Terminal & UX" ;;
    2)  echo "SSH & Key Management" ;;
    3)  echo "Git & Source Control" ;;
    4)  echo "Code & Dev Tools" ;;
    5)  echo "Containers & Runtimes" ;;
    6)  echo "Kubernetes (Local Dev)" ;;
    7)  echo "Secrets & Certs" ;;
    8)  echo "Observability & Logs" ;;
    9)  echo "Infrastructure as Code" ;;
    10) echo "Automation & Scheduling" ;;
    11) echo "🌟 Bonus Tools" ;;
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
    11) echo "" ;; # bonus menu is not driven by a domain JSON
  esac
}

# Calculate domain status by checking if all MUST tools are installed in state
_sr_domain_status_line() {
  local idx="$1"
  local title="$(_sr_domain_title "$idx")"
  local json="$(_sr_domain_json "$idx")"

  # Bonus tools: just show as available (no status math)
  if [ "$idx" = "11" ]; then
    printf "%2s: %-28s  %s\n" "$idx" "$title" "🧩 Available"
    return
  fi

  # No jq / no state / no json -> neutral pending
  if ! have jq || [ ! -f "$SR_VERSION_STATE" ] || [ ! -s "$SR_VERSION_STATE" ] || [ ! -f "$json" ]; then
    printf "%2s: %-28s  %s\n" "$idx" "$title" "🕒 Pending"
    return
  fi

  # pull MUST tools for this domain
  local tools
  tools="$(jq -r '.tools.must[]?' "$json" 2>/dev/null || true)"
  if [ -z "$tools" ]; then
    # no must tools? call it pending but harmless
    printf "%2s: %-28s  %s\n" "$idx" "$title" "🕒 Pending"
    return
  fi

  # count installed in state
  local total=0 okc=0
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    total=$((total+1))
    # state: .[t].installed == true
    if jq -e --arg tool "$t" '.[ $tool ].installed == true' "$SR_VERSION_STATE" >/dev/null 2>&1; then
      okc=$((okc+1))
    fi
  done <<< "$tools"

  if [ "$total" -gt 0 ] && [ "$okc" -eq "$total" ]; then
    printf "%2s: %-28s  %s %d/%d\n" "$idx" "$title" "✅ Complete" "$okc" "$total"
  else
    printf "%2s: %-28s  %s %d/%d\n" "$idx" "$title" "🕒 Pending" "$okc" "$total"
  fi
}

# Build the menu lines with live status
_sr_build_menu_items() {
  local items=()
  local i
  for i in {1..11}; do
    items+=("$(_sr_domain_status_line "$i")")
  done
  items+=(" A: Install ALL MUST (all domains)")
  items+=(" Q: Quit")
  printf '%s\n' "${items[@]}"
}

# Map a short answer (1..11/A/Q) to the visible line prefix (so caller can route)
_sr_map_quick_choice() {
  local ans="$1"
  case "$ans" in
    1)  echo "1" ;;  2)  echo "2" ;;  3)  echo "3" ;;
    4)  echo "4" ;;  5)  echo "5" ;;  6)  echo "6" ;;
    7)  echo "7" ;;  8)  echo "8" ;;  9)  echo "9" ;;
    10) echo "10" ;; 11) echo "11" ;;
    A|a) echo "A" ;;
    Q|q) echo "Q" ;;
    *)   echo "" ;;
  esac
}

# Present main menu and return the selection token on STDOUT:
# 1..11 / A / Q
sr_menu_main() {
  # Render header
  hr
  say "🧭 stack_refreshr — Main Menu"
  hr

  # Build items with live status
  mapfile -t items < <(_sr_build_menu_items)
  for it in "${items[@]:0:11}"; do say "  $it"; done
  say "  ${items[11]}"
  say "  ${items[12]}"
  hr

  # If gum is available, immediately enable arrow navigation without echoing escape codes.
  # Still support single-key shortcuts: 1–11/A/Q (no Enter needed).
  local picked="" ans=""
  if have gum; then
    say "Use ↑/↓ then Enter, or press [1–11/A/Q] for quick select…"
    # read a single key w/out echo from the TTY; if it's not a shortcut, open chooser
    IFS= read -r -n1 -s ans </dev/tty || ans=""
    case "$ans" in
      [1-9])
        picked="$(_sr_map_quick_choice "$ans")"
        ;;
      1)  picked="1" ;; 2) picked="2" ;; 3) picked="3" ;; # (kept for clarity)
      A|a|Q|q)
        picked="$(_sr_map_quick_choice "$ans")"
        ;;
      0)  # could be start of 10/11; read one more char quickly
        IFS= read -r -n1 -s ans2 </dev/tty || ans2=""
        case "${ans}${ans2}" in
          10) picked="10" ;;
          11) picked="11" ;;
          *)  picked="" ;;
        esac
        ;;
      *)
        # open the chooser — arrows fully supported
        picked="$(printf '%s\n' "${items[@]}" \
          | gum choose --header 'Select a domain or action (↑/↓, Enter)')" || picked=""
        ;;
    esac
  elif have fzf; then
    picked="$(printf '%s\n' "${items[@]}" \
      | fzf --prompt='Select > ' --height=80% --border)" || picked=""
  else
    # Plain input fallback
    say "Type 1–11 / A / Q and press Enter:"
    IFS= read -r ans || ans=""
    ans="$(_trim "$ans")"
    picked="$(_sr_map_quick_choice "$ans")"
  fi

  # If we got a full line from gum/fzf (e.g., "  1: Terminal & UX  ✅ 7/7"), reduce to token
  if [ -n "$picked" ] && [[ "$picked" != [0-9AQaq]* ]]; then
    picked="$(printf '%s' "$picked" | _strip_ansi | tr -d '\r')"
    picked="$(_trim "$picked")"
    # Extract the leading code (before ':' or space)
    case "$picked" in
      [0-9]*:*) picked="${picked%%:*}";;
      "A:"*)    picked="A";;
      "Q:"*)    picked="Q";;
      "A"|"Q")  ;; # already good
      *)
        # Line like "11: 🌟 Bonus Tools  🧩 Available"
        if [[ "$picked" =~ ^([0-9]+) ]]; then
          picked="${BASH_REMATCH[1]}"
        fi
        ;;
    esac
  fi

  [ -n "$picked" ] || { printf ""; return 0; }
  printf '%s\n' "$picked"
}

sr_select_multi() {
  local prompt="$1"; shift
  local items=("$@")

  local out
  if have gum; then
    out="$(printf '%s\n' "${items[@]}" | gum choose --no-limit --cursor="▶" --header "$prompt" || true)"
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
      [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#items[@]}" ] && sel+=("${items[$((n-1))]}")
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
