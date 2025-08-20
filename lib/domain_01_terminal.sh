# lib/domain_01_terminal.sh
#!/usr/bin/env bash
set -euo pipefail
sr_domain_01_terminal() {
  sr_domain_from_json "$SR_CONF/domains/domain_01_terminal.json" "${1:-full}"
}
