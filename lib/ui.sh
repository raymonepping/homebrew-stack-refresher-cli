#!/usr/bin/env bash
set -euo pipefail

have(){ command -v "$1" >/dev/null 2>&1; }

# --- everything visual -> stderr (so it won't get captured) ---
hr(){ printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '─' >&2; }
say(){ printf "%s\n" "$*" >&2; }
_trim(){ printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
_strip_ansi(){ sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'; }

# Map a short answer (1..10/A/Q) to the full "N: Title" line
_sr_map_quick_choice() {
  local ans="$1"
  case "$ans" in
    1)  echo "1: Terminal & UX" ;;
    2)  echo "2: SSH & Key Management" ;;
    3)  echo "3: Git & Source Control" ;;
    4)  echo "4: Code & Dev Tools" ;;
    5)  echo "5: Containers & Runtimes" ;;
    6)  echo "6: Kubernetes (Local Dev)" ;;
    7)  echo "7: Secrets & Certs" ;;
    8)  echo "8: Observability & Logs" ;;
    9)  echo "9: Infrastructure as Code" ;;
    10) echo "10: Automation & Scheduling" ;;
    A|a) echo "A: Install ALL MUST (all domains)" ;;
    Q|q) echo "Q: Quit" ;;
    *)   echo "" ;;
  esac
}

sr_menu_main() {
  local items=(
    "1: Terminal & UX"
    "2: SSH & Key Management"
    "3: Git & Source Control"
    "4: Code & Dev Tools"
    "5: Containers & Runtimes"
    "6: Kubernetes (Local Dev)"
    "7: Secrets & Certs"
    "8: Observability & Logs"
    "9: Infrastructure as Code"
    "10: Automation & Scheduling"
    "A: Install ALL MUST (all domains)"
    "Q: Quit"
  )

  # draw header to STDERR only
  hr
  say "🧭 stack_refreshr — Main Menu"
  hr
  for it in "${items[@]}"; do say "  $it"; done
  hr

  # Hybrid input:
  # 1) quick numeric/letter selection
  # 2) if empty/invalid, fall back to gum/fzf picker with arrows
  local picked="" ans=""
  say "Type 1–10 / A / Q and Enter, or just press Enter to browse (↑/↓ + Enter): "
  IFS= read -r ans || ans=""
  ans="$(_trim "$ans")"
  picked="$(_sr_map_quick_choice "$ans")"

  if [ -z "$picked" ]; then
    if have gum; then
      picked="$(printf '%s\n' "${items[@]}" \
        | gum choose --header 'Select an option (↑/↓, Enter)')" || picked=""
    elif have fzf; then
      picked="$(printf '%s\n' "${items[@]}" \
        | fzf --prompt='Select > ' --height=80% --border)" || picked=""
    else
      # plain input fallback
      say "Select (1–10/A/Q): "
      IFS= read -r ans || ans=""
      picked="$(_sr_map_quick_choice "$ans")"
    fi
  fi

  # sanitize: strip ANSI + CRs, trim whitespace
  picked="$(printf '%s' "$picked" | _strip_ansi | tr -d '\r')"
  picked="$(_trim "$picked")"

  # Return empty on cancel → caller reprompts
  [ -n "$picked" ] || { printf ""; return 0; }

  # Return only the code before the colon on STDOUT (captured by caller)
  printf '%s\n' "${picked%%:*}"
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

  # sanitize & print only non-empty lines
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
