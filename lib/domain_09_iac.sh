# lib/domain_09_iac.sh
#!/usr/bin/env bash
set -euo pipefail
sr_domain_09_iac() { sr_domain_from_json "$SR_CONF/domains/domain_09_iac.json" "${1:-full}"; }
