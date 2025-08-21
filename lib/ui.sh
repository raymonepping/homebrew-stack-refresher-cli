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

# After the SR_* vars:
[ -f "$SR_ROOT/lib/polish.sh" ] && . "$SR_ROOT/lib/polish.sh" || SR_POLISH=0

# Column override (if set), otherwise computed dynamically per menu build
: "${SR_STATUS_COL:=38}"

# Show status column? 0 = OFF (default), 1 = ON
: "${SR_SHOW_STATUS:=0}"

_goto_col() {
  local col="$1"
  if command -v tput >/dev/null 2>&1; then
    [ "$col" -lt 1 ] && col=1
    tput hpa $((col-1))
  else
    printf '\033[%dG' "$col"
  fi
}

# Icons (emoji) and plain ASCII labels per domain
_sr_domain_icon() {
  case "$1" in
    1)  echo "🖥️" ;;
    2)  echo "🔑" ;;
    3)  echo "🧬" ;;
    4)  echo "⚙️" ;;
    5)  echo "🐳" ;;
    6)  echo "⎈" ;;
    7)  echo "🔐" ;;
    8)  echo "📊" ;;
    9)  echo "🏗️" ;;
    10) echo "⏱️" ;;
    11) echo "🌟" ;;
  esac
}
_sr_domain_label() {
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
    11) echo "Bonus Tools (CLI Suite)" ;;
  esac
}

# Domain -> JSON path (same as before)
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

# Remove VS16/VS15 + ZWJ so display matches our width calculation
_strip_zw() {
  sed -e 's/\xEF\xB8\x8F//g' -e 's/\xEF\xB8\x8E//g' -e 's/\xE2\x80\x8D//g'
}

# --- width-aware padding (no awk [:ascii:] class; robust on macOS) ---
_visible_width() {
  local s; s="$(printf '%s' "$1" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')"
  s="$(printf '%s' "$s" \
      | sed -e 's/\xef\xb8\x8f//g' \
            -e 's/\xef\xb8\x8e//g' \
            -e 's/\xe2\x80\x8d//g')"
  local total ascii non
  total=$(printf '%s' "$s" | wc -m | awk '{print $1}')
  ascii=$(printf '%s' "$s" | LC_ALL=C tr -cd '\000-\177' | wc -m | awk '{print $1}')
  non=$(( total - ascii ))
  local w=$(( ascii + non * 2 ))
  local helm_count
  helm_count=$(printf '%s' "$s" | grep -o '⎈' | wc -l | awk '{print $1}')
  if [ "$helm_count" -gt 0 ]; then
    w=$(( w - helm_count ))
  fi
  printf '%d\n' "$w"
}

_pad_to_col() {
  local left="$1" target="$2"
  local w pad
  w="$(_visible_width "$left")"
  pad=$(( target - w ))
  if [ "$pad" -lt 1 ]; then
    printf "%s" "$left"
  else
    printf "%s%*s" "$left" "$pad" ""
  fi
}

_emit_row() {
  local idx="$1" icon="$2" label="$3" status="$4"
  local INDENT="  "
  printf "%s%2s: %s %s" "$INDENT" "$idx" "$icon" "$label"
  if [ "${SR_SHOW_STATUS:-0}" = "1" ]; then
    _goto_col "${SR_STATUS_COL:-38}"
    printf "%s\n" "$status"
  else
    printf "\n"
  fi
}

# Calculate domain status by checking MUST tools, then print with _emit_row
_sr_row_parts() {
  local idx="$1"
  local icon="$(_sr_domain_icon "$idx")"
  local label="$(_sr_domain_label "$idx")"
  local json="$(_sr_domain_json "$idx")"

  local left_prefix left_block status_phrase
  left_prefix="$(printf "  %2s: " "$idx")"
  left_block="${left_prefix}${icon} ${label}"

  if [ "$idx" = "11" ]; then
    printf "%s\t%s\n" "$left_block" "🧩 Available"
    return
  fi

  if ! have jq || [ ! -s "$SR_VERSION_STATE" ] || [ ! -f "$json" ]; then
    printf "%s\t%s\n" "$left_block" "🕒 Pending"
    return
  fi

  local tools total=0 okc=0
  tools="$(jq -r '.tools.must[]?' "$json" 2>/dev/null || true)"
  if [ -z "$tools" ]; then
    printf "%s\t%s\n" "$left_block" "🕒 Pending"
    return
  fi

  while IFS= read -r t; do
    [ -n "$t" ] || continue
    total=$((total+1))
    jq -e --arg tool "$t" '.[ $tool ].installed == true' "$SR_VERSION_STATE" >/dev/null 2>&1 && okc=$((okc+1))
  done <<< "$tools"

  if [ "$total" -gt 0 ] && [ "$okc" -eq "$total" ]; then
    status_phrase="✅ Complete $okc/$total"
  else
    status_phrase="🕒 Pending $okc/$total"
  fi

  printf "%s\t%s\n" "$left_block" "$status_phrase"
}

# Build menu with live status, perfectly aligned to the widest left block
_sr_build_menu_items() {
  local LEFTS=() STATUSES=() i parts left status
  local max_left=0 w

  for i in {1..11}; do
    parts="$(_sr_row_parts "$i")"
    left="${parts%%$'\t'*}"
    status="${parts#*$'\t'}"
    LEFTS+=("$left")
    STATUSES+=("$status")
    w="$(_visible_width "$left")"
    [ "$w" -gt "$max_left" ] && max_left="$w"
  done

  # Decide status column: honor override if set; else derive from content
  local STATUS_COL_COMPUTED=$(( max_left + 2 ))
  local STATUS_COL="${SR_STATUS_COL:-$STATUS_COL_COMPUTED}"

  # Emit aligned rows
  for i in "${!LEFTS[@]}"; do
    clean_left="$(printf '%s' "${LEFTS[$i]}" | _strip_zw)"
    if [ "${SR_SHOW_STATUS:-0}" = "1" ]; then
      _pad_to_col "$clean_left" "$STATUS_COL"
      printf "%s\n" "${STATUSES[$i]}"
    else
      printf "%s\n" "$clean_left"
    fi
  done

  printf '%s\n' "  A: Install ALL MUST (all domains)"
  printf '%s\n' "  Q: Quit"
}

# Map quick keys -> token
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

# Main menu: returns 1..11 / A / Q on STDOUT
sr_menu_main() {
  hr
  if [ "${SR_POLISH:-0}" -eq 1 ]; then
    polish_banner "stack_refreshr  —  Main Menu" >&2
  else
    say "🧭 stack_refreshr — Main Menu"
  fi
  hr

  mapfile -t items < <(_sr_build_menu_items)
  for it in "${items[@]:0:11}"; do say "$it"; done
  say "${items[11]}"
  say "${items[12]}"

  local picked="" ans=""
  if have gum; then
    say "Use ↑/↓ then Enter, or press [1–11/A/Q] for quick select…"
    IFS= read -r -n1 -s ans </dev/tty || ans=""
    case "$ans" in
      [1-9]) picked="$(_sr_map_quick_choice "$ans")" ;;
      A|a|Q|q) picked="$(_sr_map_quick_choice "$ans")" ;;
      0)
        IFS= read -r -n1 -s ans2 </dev/tty || ans2=""
        case "${ans}${ans2}" in 10) picked="10" ;; 11) picked="11" ;; esac
        ;;
      *)
        picked="$(printf '%s\n' "${items[@]}" | gum choose --header 'Select a domain or action (↑/↓, Enter)')" || picked=""
        ;;
    esac
  elif have fzf; then
    picked="$(printf '%s\n' "${items[@]}" | fzf --prompt='Select > ' --height=80% --border)" || picked=""
  else
    say "Type 1–11 / A / Q and press Enter:"
    IFS= read -r ans || ans=""
    picked="$(_sr_map_quick_choice "$(_trim "$ans")")"
  fi

  if [ -n "$picked" ] && [[ "$picked" != [0-9AQaq]* ]]; then
    picked="$(printf '%s' "$picked" | _strip_ansi | tr -d '\r')"
    picked="$(_trim "$picked")"
    case "$picked" in
      [0-9]*:*) picked="${picked%%:*}" ;;
      "A:"*)    picked="A" ;;
      "Q:"*)    picked="Q" ;;
      "A"|"Q")  ;;
      *) [[ "$picked" =~ ^([0-9]+) ]] && picked="${BASH_REMATCH[1]}" ;;
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
