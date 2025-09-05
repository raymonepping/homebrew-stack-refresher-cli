# lib/domain_10_automation.sh
#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

sr_domain_10_automation() { sr_domain_from_json "$SR_CONF/domains/domain_10_automation.json" "${1:-full}"; }
