# lib/domain_01_terminal.sh
#!/usr/bin/env bash
set -euo pipefail

# If helpers/say are already sourced earlier, keep as-is
# Source timer utils
. "$SR_ROOT/lib/timer.sh"

# Start a timer just for this domain
timer_start "domain_01"

sr_domain_01_terminal() {
  sr_domain_from_json "$SR_CONF/domains/domain_01_terminal.json" "${1:-full}"
  # Ensure Nerd Font is installed and wired into iTerm2 (idempotent)
  sr_install_nerd_font
  sr_set_iterm2_font
}

timer_end_say "domain_01"