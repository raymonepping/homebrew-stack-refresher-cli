# lib/domain_07_secrets.sh
#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

sr_domain_07_secrets() { sr_domain_from_json "$SR_CONF/domains/domain_07_secrets.json" "${1:-full}"; }
