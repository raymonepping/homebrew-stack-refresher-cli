#!/usr/bin/env bash
set -euo pipefail

sr_domain_01_terminal() {
  sr_domain_from_json "$SR_CONF/domains/domain_01_terminal.json" "${1:-full}"

  # Fonts + iTerm2 (idempotent)
  sr_install_nerd_font
  sr_set_iterm2_font

  # Optional polish info
  if [ "${SR_POLISH:-0}" -eq 1 ]; then
    if have fastfetch; then
      # Safely try a “nice” run, fall back to default
      if fastfetch --logo small --pipe >/dev/null 2>&1; then
        fastfetch --logo small --pipe | while IFS= read -r l; do say "$l"; done
      else
        fastfetch | while IFS= read -r l; do say "$l"; done
      fi
    elif have neofetch; then
      neofetch 2>/dev/null | while IFS= read -r l; do say "$l"; done
    fi
  fi
}
