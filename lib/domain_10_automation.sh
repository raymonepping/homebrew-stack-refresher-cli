# lib/domain_10_automation.sh
#!/usr/bin/env bash
set -euo pipefail
sr_domain_10_automation() { sr_domain_from_json "$SR_CONF/domains/domain_10_automation.json" "${1:-full}"; }