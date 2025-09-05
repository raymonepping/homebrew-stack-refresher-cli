#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

sr_domain_01_terminal() {
  sr_domain_from_json "$SR_CONF/domains/domain_01_terminal.json" "${1:-full}"

  # Fonts + iTerm2 (idempotent)
  sr_install_nerd_font
  sr_install_shell_completions || true
  # sr_set_iterm2_font

# Optional system summary (OFF by default; enable with SR_SHOW_SYSTEM=1 or --show-system)
if [ "${SR_SHOW_SYSTEM:-0}" = "1" ]; then
  if have fastfetch; then
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
