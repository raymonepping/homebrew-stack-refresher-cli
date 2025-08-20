#!/usr/bin/env bash
set -euo pipefail

# Globals the caller can read after sr_domain_from_json:
#   SR_LAST_SHOULD_PICKS, SR_LAST_COULD_PICKS
unset SR_LAST_SHOULD_PICKS SR_LAST_COULD_PICKS
declare -a SR_LAST_SHOULD_PICKS SR_LAST_COULD_PICKS

# Load a domain from a JSON manifest and run the flow.
# Usage: sr_domain_from_json "$SR_CONF/domains/domain_04_code.json" [must-only|full]
sr_domain_from_json() {
  local json_file="$1"
  local mode="${2:-full}"

  local title domain
  title="$(jq -r '.title' "$json_file")"
  domain="$(jq -r '.domain' "$json_file")"

  printf "🧩 Domain — %s\n" "$title"

  # MUST
  mapfile -t __must < <(jq -r '.tools.must[]?' "$json_file")
  sr_install_group "$title" must "${__must[@]:-}"

  # Early exit for "All MUST"
  if [ "$mode" = "must-only" ]; then
    printf "✅ %s MUST complete\n" "$title"
    SR_LAST_SHOULD_PICKS=()
    SR_LAST_COULD_PICKS=()
    return 0
  fi

  # SHOULD (multi-select)
  mapfile -t __should < <(jq -r '.tools.should[]?' "$json_file")
  mapfile -t SR_LAST_SHOULD_PICKS < <(sr_select_multi "Pick SHOULD tools for $title (Enter to skip)" "${__should[@]:-}" || true)
  ((${#SR_LAST_SHOULD_PICKS[@]})) && sr_install_group "$title" should "${SR_LAST_SHOULD_PICKS[@]}"

  # COULD (opt-in, multi-select)
  mapfile -t __could < <(jq -r '.tools.could[]?' "$json_file")
  if ((${#__could[@]})) && sr_confirm "Show COULD tools for $title?"; then
    mapfile -t SR_LAST_COULD_PICKS < <(sr_select_multi "Pick COULD tools" "${__could[@]}" || true)
    ((${#SR_LAST_COULD_PICKS[@]})) && sr_install_group "$title" could "${SR_LAST_COULD_PICKS[@]}"
  else
    SR_LAST_COULD_PICKS=()
  fi

  printf "✅ Domain %s complete\n" "$title"
}
