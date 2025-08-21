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

# configurable column; not used in minimal menu, but kept for future
: "${SR_STATUS_COL:=38}"
: "${SR_SHOW_STATUS:=0}"   # minimal menu (no right-hand status)

# ---------------------------
# UI mode selection (auto/gum/fzf/basic)
# ---------------------------
: "${UI_MODE:=auto}"

_sr_ui_guess() {
  if have gum; then echo gum
  elif have fzf; then echo fzf
  else echo basic
  fi
}

# If UI_MODE is "auto", resolve to concrete mode
if [ "$UI_MODE" = "auto" ] || [ -z "${UI_MODE:-}" ]; then
  UI_MODE="$(_sr_ui_guess)"
fi
export UI_MODE

# ---------------------------
# Zero-width / width helpers
# ---------------------------
_strip_zw() {
  sed -e 's/\xEF\xB8\x8F//g' -e 's/\xEF\xB8\x8E//g' -e 's/\xE2\x80\x8D//g'
}

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

_goto_col() {
  local col="$1"
  if command -v tput >/dev/null 2>&1; then
    [ "$col" -lt 1 ] && col=1
    tput hpa $((col-1))
  else
    printf '\033[%dG' "$col"
  fi
}

# ---------------------------
# Domain icon/label/json
# ---------------------------
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

# ---------------------------
# Minimal menu rows (no status on the right)
# ---------------------------
_sr_build_menu_items() {
  for i in {1..11}; do
    printf "  %2s: %s %s\n" "$i" "$(_sr_domain_icon "$i")" "$(_sr_domain_label "$i")"
  done
  printf '%s\n' "  A: Install ALL MUST (all domains)"
  printf '%s\n' "  Q: Quit"
}

# ---------------------------
# UI wrappers
# ---------------------------
sr_ui_choose_one() {
  # args: header; stdin: choices (one per line)
  local header="${1:-Select}"
  local out
  case "$UI_MODE" in
    gum)
      out="$(gum choose --header "$header" || true)"
      ;;
    fzf)
      out="$(fzf --prompt="$header > " --height=80% --border || true)"
      ;;
    *)
      # basic: print list with numbers and read
      say "$header"
      local items=() i=1 line sel=""
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        items+=("$line")
        say " [$i] $line"
        i=$((i+1))
      done
      say "Pick number (Enter cancels):"
      local n=""; IFS= read -r n || true
      if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#items[@]}" ]; then
        sel="${items[$((n-1))]}"
      fi
      out="$sel"
      ;;
  esac
  printf '%s' "$out"
}

sr_ui_choose_many() {
  # args: header; stdin: choices
  local header="${1:-Select}"
  local out
  case "$UI_MODE" in
    gum)
      out="$(gum choose --no-limit --cursor="▶" --header "$header" || true)"
      ;;
    fzf)
      out="$(fzf --multi --prompt="$header > " --height=80% --border || true)"
      ;;
    *)
      # basic: multi via space-separated numbers
      say "$header"
      local items=() i=1 line
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        items+=("$line")
        say " [$i] $line"
        i=$((i+1))
      done
      say "Pick numbers (space-separated, Enter=none):"
      local picks=""; IFS= read -r picks || true
      local sel=() n
      for n in $picks; do
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#items[@]}" ] && sel+=("${items[$((n-1))]}")
      done
      out="$(printf '%s\n' "${sel[@]:-}")"
      ;;
  esac
  printf '%s' "$out"
}

sr_ui_confirm() {
  # arg: message; return 0/1
  local msg="$1"
  case "$UI_MODE" in
    gum) gum confirm "$msg" ;;
    *)
      say "$msg [y/N] "
      local a=""; IFS= read -r a || true
      [[ "$a" =~ ^[Yy]$ ]]
      ;;
  esac
}

# ---------------------------
# Map quick keys -> token
# ---------------------------
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

# ---------------------------
# Main menu (uses UI wrappers)
# ---------------------------
sr_menu_main() {
  hr
  if [ "${SR_POLISH:-0}" -eq 1 ]; then
    polish_banner "stack_refreshr  —  Main Menu" >&2
  else
    say "🧭 stack_refreshr — Main Menu"
  fi
  hr

  mapfile -t items < <(_sr_build_menu_items)

  # Print the menu (to stderr)
  for it in "${items[@]:0:11}"; do say "$it"; done
  say "${items[11]}"
  say "${items[12]}"

  # Fast single-key path when gum is present (nice UX)
  local picked="" ans=""
  if [ "$UI_MODE" = "gum" ]; then
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
        picked="$(printf '%s\n' "${items[@]}" | sr_ui_choose_one 'Select a domain or action')" || picked=""
        ;;
    esac
  else
    # fzf/basic path — just use the wrapper
    picked="$(printf '%s\n' "${items[@]}" | sr_ui_choose_one 'Select a domain or action')" || picked=""
  fi

  # Reduce full line to token
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

# ---------------------------
# Multi-select & confirm (wrappers)
# ---------------------------
sr_select_multi() {
  local prompt="$1"; shift
  local items=("$@")
  local out
  out="$(printf '%s\n' "${items[@]}" | sr_ui_choose_many "$prompt")"
  out="$(printf '%s\n' "$out" | _strip_ansi | tr -d '\r' | sed '/^$/d')"
  [ -n "$out" ] && printf '%s\n' "$out"
}

sr_confirm() {
  local msg="$1"
  sr_ui_confirm "$msg"
}
