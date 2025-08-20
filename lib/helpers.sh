#!/usr/bin/env bash
set -euo pipefail

# Utility: run a domain function if it exists, otherwise warn
sr_run_or_warn() {
  local fn="$1"; shift || true
  if command -v "$fn" >/dev/null 2>&1; then
    "$fn" "$@"
  else
    printf "⚠️  %s not implemented yet\n" "$fn"
  fi
}

# Optional: tiny helper used elsewhere if needed
sr_fn_exists() { command -v "$1" >/dev/null 2>&1; }
