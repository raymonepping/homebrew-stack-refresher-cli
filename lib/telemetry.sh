#!/usr/bin/env bash
set -euo pipefail

# Dependencies:
# - jq (for JSON)
# - curl or gh (either works; gh preferred if authenticated)
# - say() should exist (from your helpers/ui)

# Default config path
: "${SR_CFG_DIR:="$HOME/.config/stack_refreshr"}"
: "${SR_TELEM_CFG:="$SR_CFG_DIR/telemetry.json"}"
: "${SR_LOGS:="${SR_LOGS:-$SR_ROOT/logs}"}"
mkdir -p "$SR_CFG_DIR" "$SR_LOGS"

have(){ command -v "$1" >/dev/null 2>&1; }

# --- load config (safe defaults) ---
telemetry_load_cfg() {
  # Defaults if no config file
  TELEM_ENABLED="${TELEM_ENABLED:-0}"
  TELEM_UPLOAD_URL="${TELEM_UPLOAD_URL:-https://api.github.com/gists}"
  TELEM_GIST_ID="${TELEM_GIST_ID:-}"
  TELEM_DRY_RUN="${TELEM_DRY_RUN:-0}"
  TELEM_FIELDS_DEFAULT='["domain","status","version","duration_sec","timestamp","refreshr_version"]'
  TELEM_FIELDS="${TELEM_FIELDS:-$TELEM_FIELDS_DEFAULT}"

  if [ -s "$SR_TELEM_CFG" ] && have jq; then
    # enabled
    v="$(jq -r '.enabled // empty' "$SR_TELEM_CFG" || true)"; [ -n "$v" ] && TELEM_ENABLED="$v"
    # upload_url
    v="$(jq -r '.upload_url // empty' "$SR_TELEM_CFG" || true)"; [ -n "$v" ] && TELEM_UPLOAD_URL="$v"
    # gist_id
    v="$(jq -r '.gist_id // empty' "$SR_TELEM_CFG" || true)"; [ -n "$v" ] && TELEM_GIST_ID="$v"
    # github_token path not read here (we NEVER write secrets into code), see telemetry_token()
    # fields
    v="$(jq -c '.fields // empty' "$SR_TELEM_CFG" || true)"; [ -n "$v" ] && TELEM_FIELDS="$v"
  fi

  export TELEM_ENABLED TELEM_UPLOAD_URL TELEM_GIST_ID TELEM_DRY_RUN TELEM_FIELDS
}

# --- token discovery (never hard-code) ---
telemetry_token() {
  # Priority: env var, gh CLI, macOS Keychain, else empty
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    printf '%s' "$GITHUB_TOKEN"
    return 0
  fi
  if have gh; then
    # gh prints a token if you're logged in; returns non-zero otherwise
    if tok="$(gh auth token 2>/dev/null || true)"; then
      [ -n "$tok" ] && printf '%s' "$tok" && return 0
    fi
  fi
  # macOS keychain (optional): item named "stack_refreshr_github_token"
  if have security; then
    if tok="$(security find-generic-password -s stack_refreshr_github_token -w 2>/dev/null || true)"; then
      [ -n "$tok" ] && printf '%s' "$tok" && return 0
    fi
  fi
  printf ''  # no token found
}

# --- filename per-day to avoid large single file ---
telemetry_filename_for_today() {
  date +"telemetry-%Y-%m-%d.jsonl"
}

# --- build minimal payload (jq if present) ---
telemetry_payload_json() {
  # args: domain status duration_sec [version] [extra_kv_json]
  local domain="$1" status="$2" duration="${3:-0}" version="${4:-}"
  local extra_json="${5:-}"   # optional, must be valid JSON object fragment (e.g. {"tool":"ripgrep"})
  local ts refreshr_ver
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  refreshr_ver="${SR_VERSION:-0.0.0}"

  if have jq; then
    jq -n --arg d "$domain" --arg s "$status" --arg v "$version" \
          --arg ts "$ts" --arg rv "$refreshr_ver" --argjson dur "${duration:-0}" '
      {domain:$d, status:$s, version:$v, duration_sec:($dur|tonumber), timestamp:$ts, refreshr_version:$rv}
    ' | jq -c ". + (${extra_json:-{}})"
  else
    # Very simple JSON (no escaping for special chars)
    printf '{"domain":"%s","status":"%s","version":"%s","duration_sec":%s,"timestamp":"%s","refreshr_version":"%s"}' \
      "$domain" "$status" "$version" "${duration:-0}" "$ts" "$refreshr_ver"
  fi
}

# --- local log fallback (no token) ---
telemetry_local_append() {
  local line="$1"
  local file="$SR_LOGS/$(telemetry_filename_for_today)"
  printf '%s\n' "$line" >> "$file"
  say "📝 Telemetry (local): appended to $file"
}

# --- send to Gist via gh or curl ---
telemetry_append_to_gist() {
  local line="$1"
  local filename="$2"
  local gist_id="${TELEM_GIST_ID:-}"

  if [ -z "$gist_id" ]; then
    # Create a new private gist once
    local desc="stack_refreshr telemetry"
    if have gh; then
      # gh: create with initial file content
      gist_id="$(GH_TOKEN="$(telemetry_token)" gh api -X POST /gists -f description="$desc" -F public=false \
        -F "files[$filename][content]=$line" --jq '.id' 2>/dev/null || true)"
    else
      # curl: create
      local tok; tok="$(telemetry_token)"
      [ -z "$tok" ] && { say "⚠️ No token; falling back to local telemetry."; telemetry_local_append "$line"; return 0; }
      gist_id="$(curl -sS -H "Authorization: token $tok" \
        -H "Accept: application/vnd.github+json" \
        -X POST "$TELEM_UPLOAD_URL" \
        -d "{\"description\":\"$desc\",\"public\":false,\"files\":{\"$filename\":{\"content\":\"$line\"}}}" \
        | (have jq && jq -r '.id' || sed -n 's/.*"id":"\([^"]*\)".*/\1/p'))"
    fi
    if [ -z "$gist_id" ]; then
      say "⚠️ Failed to create gist; logging locally."
      telemetry_local_append "$line"
      return 0
    fi
    TELEM_GIST_ID="$gist_id"
    # persist gist_id to config for next time
    if have jq; then
      tmp="$(mktemp)"; touch "$SR_TELEM_CFG"
      jq --arg id "$gist_id" '.gist_id = $id' "$SR_TELEM_CFG" 2>/dev/null > "$tmp" || printf '{"gist_id":"%s"}' "$gist_id" > "$tmp"
      mv "$tmp" "$SR_TELEM_CFG"
    fi
    say "🔗 Telemetry: created gist $gist_id"
    return 0
  fi

  # Append: fetch existing, append, update
  local content=""
  if have gh; then
    content="$(GH_TOKEN="$(telemetry_token)" gh api "/gists/$gist_id" --jq ".files[\"$filename\"].content" 2>/dev/null || true)"
    content="${content}${content:+$'\n'}$line"
    GH_TOKEN="$(telemetry_token)" gh api -X PATCH "/gists/$gist_id" -F "files[$filename][content]=$content" >/dev/null 2>&1 || {
      say "⚠️ gh PATCH failed; falling back to curl/local."
      content=""  # force curl path
    }
    [ -n "$content" ] && return 0
  fi

  # curl fallback
  local tok; tok="$(telemetry_token)"
  [ -z "$tok" ] && { say "⚠️ No token; falling back to local telemetry."; telemetry_local_append "$line"; return 0; }

  # get existing content (if any)
  local existing
  existing="$(curl -sS -H "Authorization: token $tok" -H "Accept: application/vnd.github+json" \
    "$TELEM_UPLOAD_URL/$gist_id" | (have jq && jq -r ".files[\"$filename\"].content // empty" || cat) )" || existing=""
  local new_content
  if [ -n "$existing" ]; then
    new_content="${existing}"$'\n'"${line}"
  else
    new_content="$line"
  fi

  curl -sS -H "Authorization: token $tok" -H "Accept: application/vnd.github+json" \
    -X PATCH "$TELEM_UPLOAD_URL/$gist_id" \
    -d "{\"files\":{\"$filename\":{\"content\":$(printf '%s' "$new_content" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}}}" >/dev/null 2>&1 \
    || { say "⚠️ curl PATCH failed; writing locally."; telemetry_local_append "$line"; }
}

# --- public API: send one event ---
telemetry_send_event() {
  telemetry_load_cfg
  [ "${TELEM_ENABLED:-0}" = "1" ] || { say "ℹ️  Telemetry disabled."; return 0; }

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
