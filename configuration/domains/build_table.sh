#!/usr/bin/env bash
# set -euo pipefail
export LC_ALL=C
# set -o pipefail

# Usage:
#   build_table.sh DIR OUT.md [--include-could true|false] [--details true|false] [--verbose] [--quiet]
#
# Examples:
#   ./build_table.sh ./configuration/domains ./configuration/domains/table.md
#   ./build_table.sh ./configuration/domains ./configuration/domains/table.md --include-could false
#   ./build_table.sh ./configuration/domains ./configuration/domains/table.md --details false
#   ./build_table.sh ./configuration/domains ./configuration/domains/table.md --verbose
#   ./build_table.sh ./configuration/domains ./configuration/domains/table.md --quiet

# ---- Args & flags -----------------------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage: $(basename "$0") DIR OUT.md [--include-could true|false] [--details true|false] [--verbose] [--quiet]" >&2
  exit 1
fi

DIR="$1"; OUT="$2"; shift 2 || true

INCLUDE_COULD="true"   # set to "false" to hide 'could'
DETAILS="true"         # set to "false" for static ### headers
VERBOSE="false"        # --verbose to show progress
QUIET="false"          # --quiet to suppress summary

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-could) INCLUDE_COULD="${2:-true}"; shift 2;;
    --details)       DETAILS="${2:-true}"; shift 2;;
    --verbose)       VERBOSE="true"; shift;;
    --quiet)         QUIET="true"; shift;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required" >&2; exit 2; }
[[ -d "$DIR" ]] || { echo "Error: DIR not found: $DIR" >&2; exit 3; }

log() { [[ "$VERBOSE" == "true" ]] && echo "$@" >&2 || true; }
say() { [[ "$QUIET" == "true" ]] || echo "$@" >&2; }

# ---- Discover domain files (macOS/BSD-safe) --------------------------------
if ! FILE_LIST=$(ls -1 "$DIR"/domain_*.json 2>/dev/null); then
  echo "Error: no domain_*.json in $DIR" >&2
  exit 4
fi
# Sort numerically by the number after "domain_"
FILES=()
while IFS= read -r p; do
  FILES+=("$p")
done < <(printf "%s\n" $FILE_LIST | awk -F'[_.]' '{print ($2+0) "\t" $0}' | sort -n | cut -f2-)

# ---- Preflight: validate JSON files ----------------------------------------
bad=0
for f in "${FILES[@]}"; do
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "ERROR: invalid JSON -> $f" >&2
    ((bad++))
  fi
done
if (( bad > 0 )); then
  echo "Aborting due to invalid JSON in $bad file(s)." >&2
  exit 6
fi

# ---- Helpers ----------------------------------------------------------------
md_escape() { local s="${1:-}"; s="${s//|/\\|}"; printf '%s' "$s"; }

# jq normalizer stored in a single string; always invoked as:  ( $JQ_BODY )
# Supports:
#   A) { tools: [ {name, level, rationale, install?}, ... ] }
#   B) { tools: { must: [...], should: [...], could: [...] } }
#   C) { must: [...], should: [...], could: [...] }
# Handles key case-insensitivity, CRLF, and canonicalizes level values.
JQ_BODY="$(cat <<'JQ'
  def lcase:
    if type=="object" then with_entries(.key |= ascii_downcase) else . end;

  def trimtxt:
    tostring | gsub("\r"; "") | gsub("^\\s+|\\s+$"; "");

  def mk(level; item):
    if (item|type)=="object" then item + {level:level} else {name:item, level:level} end;

  def canonlevel(s):
    (s // "") | trimtxt | ascii_downcase
    | if .=="must-have" or .=="musts" then "must"
      elif .=="should-have" or .=="shoulds" then "should"
      elif .=="could-have" or .=="coulds" or .=="optional" then "could"
      else . end;

  . as $root
  | ($root|lcase) as $rt
  | (
      if ($rt.tools|type)=="array" then
        $rt.tools
      elif ($rt.tools|type)=="object" then
        (($rt.tools|lcase).must   // [] | map(mk("must"; .))) +
        (($rt.tools|lcase).should // [] | map(mk("should"; .))) +
        (($rt.tools|lcase).could  // [] | map(mk("could"; .)))
      else
        ($rt.must   // [] | map(mk("must"; .))) +
        ($rt.should // [] | map(mk("should"; .))) +
        ($rt.could  // [] | map(mk("could"; .)))
      end
    )
  | map({
      name:      (.name // "" | trimtxt),
      level:     (canonlevel(.level)),
      rationale: (.rationale // "—" | trimtxt),
      install:   (.install // "" | trimtxt)
    })
  | map(select(.name != ""))
JQ
)"

# ---- Start output -----------------------------------------------------------
: > "$OUT"
{
  echo
  echo '---'
  echo
  echo '## 📚 Domain Matrix'
  echo
  echo 'Below are the domains covered. Each domain lists must, should, and could tools with short rationales.'
} >> "$OUT"

domains_processed=0
domains_with_install=0

# ---- Render each domain -----------------------------------------------------
for f in "${FILES[@]}"; do
  log "Processing: $f"

  # Safely read meta (never fail the loop)
  title="$(jq -r '.title // empty' "$f" 2>/dev/null || true)"
  [[ -z "${title:-}" ]] && title="$(basename "$f" .json)"
  version="$(jq -r '.version // empty' "$f" 2>/dev/null || true)"
  description="$(jq -r '.description // empty' "$f" 2>/dev/null || true)"

  # Count installs — ensure numeric and guard (do NOT abort if jq fails)
  install_count=$(
    jq -r "($JQ_BODY)
| map(select(.install != \"\")) 
| length" "$f" 2>/dev/null || echo "0"
  )
  [[ "$install_count" =~ ^[0-9]+$ ]] || install_count=0
  HAS_INSTALL="false"; (( install_count > 0 )) && HAS_INSTALL="true"
  [[ "$HAS_INSTALL" == "true" ]] && ((domains_with_install++))

  # Section header
  if [[ "$DETAILS" == "true" ]]; then
    {
      echo
      echo
      echo '<details>'
      if [[ -n "${version:-}" ]]; then
        echo "<summary><strong>${title} — v${version}</strong></summary>"
      else
        echo "<summary><strong>${title}</strong></summary>"
      fi
      [[ -n "${description:-}" ]] && { echo; echo "$(md_escape "$description")"; echo; }
    } >> "$OUT"
  else
    {
      echo
      echo
      echo '---'
      if [[ -n "${version:-}" ]]; then
        echo "### ${title} — v${version}"
      else
        echo "### ${title}"
      fi
      [[ -n "${description:-}" ]] && { echo; echo "$(md_escape "$description")"; echo; }
    } >> "$OUT"
  fi

  # Table header
  if [[ "$HAS_INSTALL" == "true" ]]; then
    {
      echo '| Level | Tool | Rationale | Install |'
      echo '|------|------|-----------|---------|'
    } >> "$OUT"
  else
    {
      echo '| Level | Tool | Rationale |'
      echo '|------|------|-----------|'
    } >> "$OUT"
  fi

  # Table rows — DO NOT let this pipeline abort the script
  if [[ "$HAS_INSTALL" == "true" ]]; then
    jq -r --arg include_could "$INCLUDE_COULD" "
      ($JQ_BODY)
      | (if \$include_could==\"true\" then . else map(select(.level!=\"could\")) end)
      | sort_by(
          ( .level | if .==\"must\" then 0 elif .==\"should\" then 1 elif .==\"could\" then 2 else 9 end ),
          ( .name | ascii_downcase )
        )
      | .[]
      | [ (.level // \"\"), (.name // \"\"), (.rationale // \"—\"), (.install // \"\") ]
      | @tsv
    " "$f" 2>/dev/null | while IFS=$'\t' read -r lvl nm rat inst; do
      printf '| %s | %s | %s | %s |\n' "$lvl" "$nm" "$(md_escape "$rat")" "$(md_escape "$inst")" >> "$OUT"
    done || { echo "WARN: failed to render rows for $f" >&2; }
  else
    jq -r --arg include_could "$INCLUDE_COULD" "
      ($JQ_BODY)
      | (if \$include_could==\"true\" then . else map(select(.level!=\"could\")) end)
      | sort_by(
          ( .level | if .==\"must\" then 0 elif .==\"should\" then 1 elif .==\"could\" then 2 else 9 end ),
          ( .name | ascii_downcase )
        )
      | .[]
      | [ (.level // \"\"), (.name // \"\"), (.rationale // \"—\") ]
      | @tsv
    " "$f" 2>/dev/null | while IFS=$'\t' read -r lvl nm rat; do
      printf '| %s | %s | %s |\n' "$lvl" "$nm" "$(md_escape "$rat")" >> "$OUT"
    done || { echo "WARN: failed to render rows for $f" >&2; }
  fi

  [[ "$DETAILS" == "true" ]] && echo -e "\n</details>" >> "$OUT"

  ((domains_processed++))
done

# Footer
{
  echo
  echo '---'
  echo
} >> "$OUT"

# ---- Friendly summary (stderr) ---------------------------------------------
say "✅ Generated: $OUT"
say "   Domains:   $domains_processed"
say "   With install column: $domains_with_install"
[[ "$INCLUDE_COULD" == "true" ]] || say "   Note: 'could' items were hidden"
[[ "$DETAILS" == "true"  ]] || say "   Note: used static headers (no <details>)"
[[ "$VERBOSE" == "true"  ]] && say "   Verbose: on"
