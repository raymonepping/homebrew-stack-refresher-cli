# lib/domain_loader.sh
#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

# Globals the caller can read after sr_domain_from_json:
#   SR_LAST_SHOULD_PICKS, SR_LAST_COULD_PICKS
unset SR_LAST_SHOULD_PICKS SR_LAST_COULD_PICKS
declare -a SR_LAST_SHOULD_PICKS SR_LAST_COULD_PICKS

# Load a domain from a JSON manifest and run the flow.
# Usage: sr_domain_from_json "$SR_CONF/domains/domain_04_code.json" [must|full]
sr_domain_from_json() {
  local json_file="$1"
  local mode="${2:-full}"   # accepted: "full" (default) or "must"

  # title/domain (be tolerant if keys are missing)
  local title domain
  title="$(jq -r '.title // "Unknown Domain"' "$json_file")"
  domain="$(jq -r '.domain // "unknown"' "$json_file")"

  printf "🧩 Domain — %s\n" "$title"

  # MUST
  mapfile -t __must < <(sr_tools_list "$json_file" must)
  sr_install_group "$title" must "${__must[@]:-}"

  # Early exit for MUST-only flows
  if [[ "$mode" == "must" || "$mode" == "must-only" ]]; then
    printf "✅ %s MUST complete\n" "$title"
    SR_LAST_SHOULD_PICKS=()
    SR_LAST_COULD_PICKS=()
    return 0
  fi

  # SHOULD (multi-select; may be empty)
  mapfile -t __should < <(sr_tools_list "$json_file" should)
  if ((${#__should[@]})); then
    mapfile -t SR_LAST_SHOULD_PICKS < <(sr_select_multi "Pick SHOULD tools for $title (Enter to skip)" "${__should[@]}" || true)
    ((${#SR_LAST_SHOULD_PICKS[@]})) && sr_install_group "$title" should "${SR_LAST_SHOULD_PICKS[@]}"
  else
    SR_LAST_SHOULD_PICKS=()
  fi

  # COULD (opt-in, multi-select; may be empty)
  mapfile -t __could < <(sr_tools_list "$json_file" could)
  if ((${#__could[@]})) && sr_confirm "Show COULD tools for $title?"; then
    mapfile -t SR_LAST_COULD_PICKS < <(sr_select_multi "Pick COULD tools" "${__could[@]}" || true)
    ((${#SR_LAST_COULD_PICKS[@]})) && sr_install_group "$title" could "${SR_LAST_COULD_PICKS[@]}"
  else
    SR_LAST_COULD_PICKS=()
  fi

  printf "✅ Domain %s complete\n" "$title"
}
