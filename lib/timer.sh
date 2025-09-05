#!/usr/bin/env bash
# Lightweight, macOS/BSD-safe timers with pretty output.
# Supports multiple simultaneous timers keyed by a label.

# shellcheck disable=SC2034
VERSION="1.0.0"

# Bash 4+ required for associative arrays (you're on Bash 5 ✅)
declare -gA _TIMER_START_EPOCH=()
declare -gA _TIMER_START_HUMAN=()

: "${SR_TIMING_STYLE:=brief}"

# Start a timer: timer_start "key"
timer_start() {
  local key="${1:-default}"
  _TIMER_START_EPOCH["$key"]="$(date +%s)"
  _TIMER_START_HUMAN["$key"]="$(date '+%H:%M:%S')"
}

# Pretty format seconds → "1h 02m 05s" / "2m 07s" / "37s"
_timer_pretty() {
  local s=$1
  local h=$(( s / 3600 ))
  local m=$(( (s % 3600) / 60 ))
  local sec=$(( s % 60 ))
  local out=""
  [ "$h" -gt 0 ] && out+="${h}h "
  [ "$m" -gt 0 ] && out+=$(printf "%dm " "$m")
  out+=$(printf "%ds" "$sec")
  printf "%s" "${out% }"
}

# One-liner end: "⏱️ <key>: 1m 07s"
timer_end_brief() {
  local key="${1:-default}"
  local start_epoch="${_TIMER_START_EPOCH["$key"]:-}"
  if [ -z "$start_epoch" ]; then
    echo "⚠️  No timer started for \"$key\"" >&2
    return 1
  fi
  local now dur
  now="$(date +%s)"
  dur=$(( now - start_epoch ))
  echo "⏱️ ${key}: $(_timer_pretty "$dur")"
  unset "_TIMER_START_EPOCH[$key]" "_TIMER_START_HUMAN[$key]"
}

# Stop & print: timer_end "key"
# Prints:
#   ⏱️ Started at 08:41:23
#   ✅ Finished at 08:42:11
#   🕒 Duration: 48s
timer_end() {
  local key="${1:-default}"
  local start_epoch="${_TIMER_START_EPOCH["$key"]:-}"
  local start_human="${_TIMER_START_HUMAN["$key"]:-}"
  local end_epoch end_human dur pretty

  if [ -z "$start_epoch" ]; then
    echo "⚠️  No timer started for \"$key\"" >&2
    return 1
  fi

  end_epoch="$(date +%s)"
  end_human="$(date '+%H:%M:%S')"
  dur=$(( end_epoch - start_epoch ))
  pretty="$(_timer_pretty "$dur")"

  echo "⏱️ Started at $start_human"
  echo "✅ Finished at $end_human"
  echo "🕒 Duration: $pretty"

  # cleanup
  unset "_TIMER_START_EPOCH[$key]" "_TIMER_START_HUMAN[$key]"
}

# Elapsed seconds without ending the timer
timer_elapsed_sec() {
  local key="${1:-default}"
  local now start dur
  now="$(date +%s)"
  start="${_TIMER_START_EPOCH["$key"]:-$now}"
  dur=$(( now - start ))
  printf '%s\n' "$dur"
}
