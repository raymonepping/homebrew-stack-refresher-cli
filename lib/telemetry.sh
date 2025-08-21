#!/usr/bin/env bash
set -euo pipefail

# telemetry.sh — GitHub Gist JSONL appender (opt-in)
# - Config path: ~/.config/stack_refreshr/telemetry.json
# - Respects: TELEM_ENABLED, TELEM_DRY_RUN, SR_TELEM_CFG, GITHUB_TOKEN, gh auth
# - Creates gist if missing; persists gist_id back into config.

# --- basic deps / helpers ---
have(){ command -v "$1" >/dev/null 2>&1; }
say(){ printf "%s\n" "$*" >&2; }

# Defaults
: "${TELEM_ENABLED:=0}"
: "${TELEM_DRY_RUN:=0}"
: "${SR_CFG_DIR:="$HOME/.config/stack_refreshr"}"
: "${SR_TELEM_CFG:="$SR_CFG_DIR/telemetry.json"}"
: "${SR_LOGS:="${SR_LOGS:-$SR_ROOT/logs}"}"
mkdir -p "$SR_CFG_DIR" "$SR_LOGS"

# --- config loader ---
telemetry_load_cfg() {
  TELEM_UPLOAD_URL="${TELEM_UPLOAD_URL:-https://api.github.com/gists}"
  TELEM_GIST_ID="${TELEM_GIST_ID:-}"
  TELEM_FIELDS_DEFAULT='["domain","status","version","duration_sec","timestamp","refreshr_version"]'
  TELEM_FIELDS="${TELEM_FIELDS:-$TELEM_FIELDS_DEFAULT}"

  if [ -s "$SR_TELEM_CFG" ] && have jq; then
    v="$(jq -r '.enabled // empty' "$SR_TELEM_CFG" 2>/dev/null || true)"; [ -n "$v" ] && TELEM_ENABLED="$v"
    v="$(jq -r '.upload_url // empty' "$SR_TELEM_CFG" 2>/dev/null || true)"; [ -n "$v" ] && TELEM_UPLOAD_URL="$v"
    v="$(jq -r '.gist_id // empty'    "$SR_TELEM_CFG" 2>/dev/null || true)"; [ -n "$v" ] && TELEM_GIST_ID="$v"
    v="$(jq -c '.fields // empty'     "$SR_TELEM_CFG" 2>/dev/null || true)"; [ -n "$v" ] && TELEM_FIELDS="$v"
  fi

  export TELEM_ENABLED TELEM_UPLOAD_URL TELEM_GIST_ID TELEM_FIELDS TELEM_DRY_RUN
}

telemetry_cfg_enabled() {
  [ -s "$SR_TELEM_CFG" ] && have jq && jq -r '.enabled // false' "$SR_TELEM_CFG" 2>/dev/null | grep -qi true
}

telemetry_enabled() {
  [ "${TELEM_ENABLED:-0}" = "1" ] || telemetry_cfg_enabled
}

# --- token discovery (never hardcode) ---
telemetry_token() {
  # 1) explicit env
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    printf '%s' "$GITHUB_TOKEN"
    return 0
  fi
  # 2) gh auth
  if have gh; then
    if tok="$(gh auth token 2>/dev/null || true)"; then
      [ -n "$tok" ] && printf '%s' "$tok" && return 0
    fi
  fi
  # 3) macOS keychain (optional)
  if have security; then
    if tok="$(security find-generic-password -s stack_refreshr_github_token -w 2>/dev/null || true)"; then
      [ -n "$tok" ] && printf '%s' "$tok" && return 0
    fi
  fi
  printf ''  # none
}

# --- utility: current day filename ---
telemetry_filename_for_today() {
  date +"telemetry-%Y-%m-%d.jsonl"
}

# --- payload builder ---
telemetry_payload_json() {
  # args: domain status duration_sec [version] [extra_json]
  local domain="$1" status="$2" duration="${3:-0}" version="${4:-}" extra_json="${5:-}"
  local ts refreshr_ver
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  refreshr_ver="${SR_VERSION:-0.0.0}"

  if have jq; then
    # build the base object
    local base
    base="$(jq -n --arg d "$domain" --arg s "$status" --arg v "$version" \
                 --arg ts "$ts" --arg rv "$refreshr_ver" --argjson dur "${duration:-0}" '
             {domain:$d, status:$s, version:$v, duration_sec:($dur|tonumber), timestamp:$ts, refreshr_version:$rv}
           ')"

    # if extra_json parses, merge it; otherwise just output base
    if [ -n "$extra_json" ] && echo "$extra_json" | jq -e . >/dev/null 2>&1; then
      jq -c -s '.[0] * .[1]' <(printf '%s' "$base") <(printf '%s' "$extra_json")
    else
      printf '%s\n' "$base"
    fi
  else
    # naive JSON if jq missing (avoid quotes in inputs please)
    printf '{"domain":"%s","status":"%s","version":"%s","duration_sec":%s,"timestamp":"%s","refreshr_version":"%s"}' \
      "$domain" "$status" "$version" "${duration:-0}" "$ts" "$refreshr_ver"
  fi
}

# --- local fallback ---
telemetry_local_append() {
  local line="$1"
  local file="$SR_LOGS/$(telemetry_filename_for_today)"
  printf '%s\n' "$line" >> "$file"
  say "📝 Telemetry (local): appended to $file"
}

# --- create gist if missing, save gist_id back to config ---
telemetry_ensure_gist() {
  [ -n "${TELEM_GIST_ID:-}" ] && return 0

  local tok; tok="$(telemetry_token)"
  [ -z "$tok" ] && { say "⚠️  No GitHub token; logging locally."; return 1; }

  local filename; filename="$(telemetry_filename_for_today)"
  local desc="stack_refreshr telemetry (JSONL events)"
  local new_id=""

  if have gh; then
    # gh expects GH_TOKEN
    GH_TOKEN="$tok" gh api -X POST /gists \
      -f description="$desc" -F public=false \
      -F "files[$filename][content]=stack_refreshr telemetry" \
      --jq '.id' >/tmp/.sr_gist_id 2>/dev/null || true
    new_id="$(cat /tmp/.sr_gist_id 2>/dev/null || true)"
    rm -f /tmp/.sr_gist_id
  fi

  if [ -z "$new_id" ]; then
    # curl fallback
    new_id="$(curl -sS -H "Authorization: token $tok" -H "Accept: application/vnd.github+json" \
      -X POST "$TELEM_UPLOAD_URL" \
      -d "{\"description\":\"$desc\",\"public\":false,\"files\":{\"$filename\":{\"content\":\"stack_refreshr telemetry\"}}}" \
      | (have jq && jq -r '.id' || sed -n 's/.*"id":"\([^"]*\)".*/\1/p'))"
  fi

  if [ -z "$new_id" ]; then
    say "⚠️  Failed to create gist; logging locally."
    return 1
  fi

  TELEM_GIST_ID="$new_id"
  export TELEM_GIST_ID

  # Persist gist_id back into config
  if have jq; then
    tmp="$(mktemp)"
    if [ -s "$SR_TELEM_CFG" ]; then
      jq --arg id "$TELEM_GIST_ID" '.gist_id = $id' "$SR_TELEM_CFG" > "$tmp" 2>/dev/null || echo "{\"gist_id\":\"$TELEM_GIST_ID\"}" > "$tmp"
    else
      echo "{\"enabled\":true,\"gist_id\":\"$TELEM_GIST_ID\"}" > "$tmp"
    fi
    mv "$tmp" "$SR_TELEM_CFG"
  else
    printf '{"enabled": true, "gist_id": "%s"}\n' "$TELEM_GIST_ID" > "$SR_TELEM_CFG"
  fi

  say "🔗 Telemetry: created gist $TELEM_GIST_ID"
  return 0
}

# --- append one JSONL line into the day file ---
telemetry_append_to_gist() {
  local line="$1"
  local filename="$2"
  local tok; tok="$(telemetry_token)"
  [ -z "$tok" ] && { telemetry_local_append "$line"; return 0; }

  # Ensure gist exists (create if needed)
  telemetry_ensure_gist || { telemetry_local_append "$line"; return 0; }

  # Fetch existing file content (if any), append, PATCH back
  local new_content
  if have gh; then
    local existing
    existing="$(GH_TOKEN="$tok" gh api "/gists/$TELEM_GIST_ID" --jq ".files[\"$filename\"].content" 2>/dev/null || true)"
    if [ -n "$existing" ]; then
      new_content="$existing"$'\n'"$line"
    else
      new_content="$line"
    fi

    GH_TOKEN="$tok" gh api -X PATCH "/gists/$TELEM_GIST_ID" \
      -F "files[$filename][content]=$new_content" >/dev/null 2>&1 && return 0

    say "⚠️  gh PATCH failed; trying curl…"
  fi

  # curl fallback
  # Build JSON with proper string escaping for 'content'
  local payload
  payload="$(python3 - <<'PY'
import json,sys,os
filename=os.environ["FILENAME"]
content=sys.stdin.read()
print(json.dumps({"files":{filename:{"content":content}}}))
PY
  )"
  export FILENAME="$filename"
  new_content="$(
    # Get existing content via curl
    curl -sS -H "Authorization: token $tok" -H "Accept: application/vnd.github+json" \
      "$TELEM_UPLOAD_URL/$TELEM_GIST_ID" \
    | (have jq && jq -r ".files[\"$filename\"].content // empty" || cat)
  )"
  [ -n "$new_content" ] && new_content="${new_content}"$'\n'"${line}" || new_content="$line"

  # Send PATCH with escaped content
  printf '%s' "$new_content" | FILENAME="$filename" python3 - <<'PY' | curl -sS \
    -H "Authorization: token '"$tok"'" -H "Accept: application/vnd.github+json" \
    -X PATCH "$TELEM_UPLOAD_URL/'"$TELEM_GIST_ID"'" \
    -d @- >/dev/null 2>&1 || { say "⚠️  curl PATCH failed; logging locally."; telemetry_local_append "$line"; exit 0; }
import json,sys,os
filename=os.environ["FILENAME"]
content=sys.stdin.read()
print(json.dumps({"files":{filename:{"content":content}}}))
PY
}

# --- public API ---
telemetry_send_event() {
  telemetry_load_cfg
  if ! telemetry_enabled; then
    say "ℹ️  Telemetry disabled."
    return 0
  fi

  local domain="$1" status="$2" duration="${3:-0}" version="${4:-}" extra="${5:-{}}"
  local jsonl; jsonl="$(telemetry_payload_json "$domain" "$status" "$duration" "$version" "$extra")"

  if [ "${TELEM_DRY_RUN:-0}" = "1" ]; then
    say "🔎 Telemetry (dry-run): $jsonl"
    return 0
  fi

  local tok; tok="$(telemetry_token)"
  local filename; filename="$(telemetry_filename_for_today)"

  if [ -z "$tok" ]; then
    telemetry_local_append "$jsonl"
    return 0
  fi

  telemetry_append_to_gist "$jsonl" "$filename"
}
