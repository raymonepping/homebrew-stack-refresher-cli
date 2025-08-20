# lib/domain_01_terminal.sh
#!/usr/bin/env bash
set -euo pipefail
sr_domain_01_terminal() {
  sr_domain_from_json "$SR_CONF/domains/domain_01_terminal.json" "${1:-full}"
  # Ensure Nerd Font is installed and wired into iTerm2 (idempotent)
  sr_install_nerd_font
  sr_set_iterm2_font
}
