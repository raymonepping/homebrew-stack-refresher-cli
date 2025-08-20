#!/usr/bin/env bash
# Lightweight, macOS/BSD-safe timers with pretty output.
# Supports multiple simultaneous timers keyed by a label.

# Bash 4+ required for associative arrays (you're on Bash 5 ✅)
declare -gA _TIMER_START_EPOCH=()
declare -gA _TIMER_START_HUMAN=()

# Start a timer: timer_start "Some Label"
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

# Stop & print: timer_end "Some Label"
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

  # Plain output by default. If you want to colorize, do it in your UI layer.
  echo "⏱️ Started at $start_human"
  echo "✅ Finished at $end_human"
  echo "🕒 Duration: $pretty"

  # cleanup
  unset "_TIMER_START_EPOCH[$key]" "_TIMER_START_HUMAN[$key]"
}

# One-shot wrapper: timer_wrap "Label" command args...
# Example: timer_wrap "Domain 5: Containers" run_containers
timer_wrap() {
  local key="$1"; shift
  timer_start "$key"
  # Run the command while preserving exit status
  local rc=0
  "$@" || rc=$?
  timer_end "$key"
  return "$rc"
}
