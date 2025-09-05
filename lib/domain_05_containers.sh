# lib/domain_05_containers.sh
#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

sr_domain_05_containers() {
  sr_domain_from_json "$SR_CONF/domains/domain_05_containers.json" "${1:-full}"
}
