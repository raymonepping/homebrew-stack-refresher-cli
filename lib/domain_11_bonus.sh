# lib/domain_11_bonus.sh
#!/usr/bin/env bash
set -euo pipefail
sr_domain_11_bonus() { sr_domain_from_json "$SR_CONF/domains/domain_11_bonus.json" "${1:-full}"; }