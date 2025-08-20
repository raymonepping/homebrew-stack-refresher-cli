# lib/domain_07_secrets.sh
#!/usr/bin/env bash
set -euo pipefail
sr_domain_07_secrets() { sr_domain_from_json "$SR_CONF/domains/domain_07_secrets.json" "${1:-full}"; }
