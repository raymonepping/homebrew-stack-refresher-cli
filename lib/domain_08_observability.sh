# lib/domain_08_observability.sh
#!/usr/bin/env bash
set -euo pipefail
sr_domain_08_observability() { sr_domain_from_json "$SR_CONF/domains/domain_08_observability.json" "${1:-full}"; }
