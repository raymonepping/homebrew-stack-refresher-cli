# lib/domain_06_k8s.sh
#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

sr_domain_06_k8s() { sr_domain_from_json "$SR_CONF/domains/domain_06_k8s.json" "${1:-full}"; }
