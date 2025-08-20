#!/usr/bin/env bash
set -euo pipefail

have(){ command -v "$1" >/dev/null 2>&1; }
ok(){ printf "✅ %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*" >&2; }
err(){ printf "❌ %s\n" "$*" >&2; }
hr(){ printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '─'; }

preflight() {
  hr; printf "✈️  Preflight checks…\n"

  # OS
  OS="$(uname -s)"
  case "$OS" in
    Darwin|Linux) ok "OS: $OS" ;;
    *) err "Unsupported OS: $OS"; exit 1 ;;
  esac

  # Bash >= 5 preferred
  V="$(bash -lc 'echo ${BASH_VERSINFO[0]:-0}' 2>/dev/null || echo 0)"
  [ "$V" -ge 5 ] && ok "Bash $V" || warn "Bash < 5 (continuing)"

  # Required
  for t in git curl; do
    have "$t" && ok "Found: $t" || { err "Missing: $t"; exit 1; }
  done

  # Recommended
  for t in jq yq fzf gum parallel; do
    have "$t" && ok "Found (opt): $t" || warn "Optional missing: $t"
  done

  # Homebrew (macOS)
  if [ "$OS" = "Darwin" ]; then
    have brew && ok "Homebrew present" || warn "Homebrew not found — installs limited"
  fi

  # GitHub reachability
  curl -sSf https://api.github.com/ >/dev/null 2>&1 && ok "Network OK" || warn "Network check failed"

  # Paths
  mkdir -p "$SR_CONF" "$SR_LOGS" "$SR_STATE"
  touch "$SR_LOGS/.w" "$SR_STATE/.w" 2>/dev/null && rm -f "$SR_LOGS/.w" "$SR_STATE/.w" || { err "Cannot write logs/state"; exit 1; }

  ok "Preflight complete"
  hr
}
