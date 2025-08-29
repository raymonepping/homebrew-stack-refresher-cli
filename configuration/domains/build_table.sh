#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.3.4"

print_help() {
  cat <<'EOF'
Usage:
  build_table.sh DIR OUT.md [options]

Description:
  Reads domain JSON files (domain_*.json) in DIR, normalizes them, and renders a Markdown
  "Domain Matrix" to OUT.md. Supports schemas:
    A) { "tools": [ {name, level, rationale, install?}, ... ] }
    B) { "tools": { "must": [...], "should": [...], "could": [...] } }
    C) { "must": [...], "should": [...], "could": [...] }
  Keys are case-insensitive, CRLF is handled, and 'level' values are canonicalized.

Options:
  --include-could true|false   Include "could" items (default: true)
  --details       true|false   Use collapsible <details> per domain (default: true)
  --verbose                    Print progress logs to stderr
  --quiet                      Suppress end-of-run summary to stderr
  -h, --help                   Show this help and exit
  -V, --version                Show version and exit

Examples:
  ./build_table.sh ./configuration/domains ./configuration/domains/table.md
  ./build_table.sh ./configuration/domains ./configuration/domains/table.md --include-could false
  ./build_table.sh ./configuration/domains ./configuration/domains/table.md --details false
  ./build_table.sh ./configuration/domains ./configuration/domains/table.md --verbose
  ./build_table.sh ./configuration/domains ./configuration/domains/table.md --quiet

Output:
  - OUT.md is overwritten.
  - A short summary is printed to stderr unless --quiet is used.

Exit codes:
  1  usage error (bad/missing args)
  2  jq not found
  3  DIR does not exist
  4  no domain_*.json found in DIR
  6  invalid JSON in one or more files

Notes:
  - Files are processed in numeric order by the domain prefix (e.g., 01..11).
  - Table includes an “Install” column only if any tool in that domain has a non-empty "install".
  - Use --include-could false to hide nice-to-haves and focus on must/should.
EOF
}

# Early flags: allow help/version without requiring DIR/OUT
case "${1:-}" in
  -h|--help)    print_help; exit 0;;
  -V|--version) echo "${SCRIPT_NAME} ${SCRIPT_VERSION}"; exit 0;;
esac

# ---- Args & flags -----------------------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage: ${SCRIPT_NAME} DIR OUT.md [--include-could true|false] [--details true|false] [--verbose] [--quiet]" >&2
  exit 1
fi

DIR="${1:-}"; OUT="${2:-}"; shift 2 || true

INCLUDE_COULD="true"   # set to "false" to hide 'could'
DETAILS="true"         # set to "false" for static ### headers
VERBOSE="false"        # --verbose to show progress
QUIET="false"          # --quiet to suppress summary

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)       print_help; exit 0;;
    -V|--version)    echo "${SCRIPT_NAME} ${SCRIPT_VERSION}"; exit 0;;
    --include-could) INCLUDE_COULD="${2:-true}"; shift 2;;
    --details)       DETAILS="${2:-true}"; shift 2;;
    --verbose)       VERBOSE="true"; shift;;
    --quiet)         QUIET="true"; shift;;
    *) echo "Unknown arg: $1" >&2; echo "Try: ${SCRIPT_NAME} --help" >&2; exit 1;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required" >&2; exit 2; }
[[ -d "$DIR" ]] || { echo "Error: DIR not found: $DIR" >&2; exit 3; }

log() { [[ "${VERBOSE}" == "true" ]] && echo "$@" >&2 || true; }
say() { [[ "${QUIET}" == "true" ]] || echo "$@" >&2; }

# ---- Discover domain files (nullglob, no ls parsing) ------------------------
shopt -s nullglob
declare -a FILES=( "${DIR}"/domain_*.json )
shopt -u nullglob
if (( ${#FILES[@]} == 0 )); then
  echo "Error: no domain_*.json in ${DIR}" >&2
  exit 4
fi

# Sort numerically by the NN after "domain_"
declare -a SORTED=()
while IFS= read -r line; do
  SORTED+=( "$line" )
done < <(
  for f in "${FILES[@]}"; do
    bn="$(basename "$f")"
    num="$(awk -F'[_.]' 'BEGIN{n=0} {if ($2 ~ /^[0-9]+$/) n=$2; print n}' <<<"$bn")"
    printf '%s\t%s\n' "$((10#$num))" "$f"
  done | sort -n | cut -f2-
)
FILES=( "${SORTED[@]}" )
unset SORTED

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
# Supports schemas A/B/C; case-insensitive keys; CRLF; canonical level values.
# NOTE: read -d '' returns non-zero; '|| true' avoids set -e abort.
read -r -d '' JQ_BODY <<'JQ' || true
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

  # Count installs — do not let jq failure abort strict mode
  install_count="$(
    { jq -r "($JQ_BODY) | map(select(.install != \"\")) | length" "$f" 2>/dev/null; } || echo "0"
  )"
  [[ "${install_count}" =~ ^[0-9]+$ ]] || install_count=0
  HAS_INSTALL="false"
  if (( install_count > 0 )); then
    HAS_INSTALL="true"
    ((domains_with_install++))
  fi

  # Section header
  if [[ "${DETAILS}" == "true" ]]; then
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
  if [[ "${HAS_INSTALL}" == "true" ]]; then
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

  # Table rows — render entirely in jq and append directly to $OUT.
  # Guard failures so set -euo won’t stop the loop.
  if [[ "${HAS_INSTALL}" == "true" ]]; then
    if ! jq -r --arg include_could "${INCLUDE_COULD}" '
      '"$JQ_BODY"'
      | (if $include_could=="true" then . else map(select(.level!="could")) end)
      | sort_by(
          ( .level | if .=="must" then 0 elif .=="should" then 1 elif .=="could" then 2 else 9 end ),
          ( .name | ascii_downcase )
        )
      | .[]
      | "| " + (.level // "")
        + " | " + (.name // "")
        + " | " + ((.rationale // "—") | gsub("\\|"; "\\\\|"))
        + " | " + ((.install   // "" ) | gsub("\\|"; "\\\\|"))
        + " |"
    ' "$f" >> "$OUT"; then
      echo "WARN: failed to render rows for $f" >&2
    fi
  else
    if ! jq -r --arg include_could "${INCLUDE_COULD}" '
      '"$JQ_BODY"'
      | (if $include_could=="true" then . else map(select(.level!="could")) end)
      | sort_by(
          ( .level | if .=="must" then 0 elif .=="should" then 1 elif .=="could" then 2 else 9 end ),
          ( .name | ascii_downcase )
        )
      | .[]
      | "| " + (.level // "")
        + " | " + (.name // "")
        + " | " + ((.rationale // "—") | gsub("\\|"; "\\\\|"))
        + " |"
    ' "$f" >> "$OUT"; then
      echo "WARN: failed to render rows for $f" >&2
    fi
  fi

  [[ "${DETAILS}" == "true" ]] && echo -e "\n</details>" >> "$OUT"
  ((domains_processed++))
done

# Footer
{
  echo
  echo '---'
  echo
} >> "$OUT"

# ---- Friendly summary (stderr) ---------------------------------------------
if [[ "${QUIET}" != "true" ]]; then
  echo "✅ Generated: $OUT" >&2
  echo "   Domains:   $domains_processed" >&2
  echo "   With install column: $domains_with_install" >&2
  [[ "${INCLUDE_COULD}" == "true" ]] || echo "   Note: 'could' items were hidden" >&2
  [[ "${DETAILS}" == "true"  ]] || echo "   Note: used static headers (no <details>)" >&2
  [[ "${VERBOSE}" == "true"  ]] && echo "   Verbose: on" >&2
fi
