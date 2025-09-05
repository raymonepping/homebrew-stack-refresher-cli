# lib/domain_08_observability.sh
#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

sr_domain_08_observability() { sr_domain_from_json "$SR_CONF/domains/domain_08_observability.json" "${1:-full}"; }
