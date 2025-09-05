#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

_sr_d3_seed_gitconfig() {
  local cfg="$HOME/.gitconfig"
  if ! grep -q "\[core\]" "$cfg" 2>/dev/null; then
    {
      echo "[core]"
      echo "  editor = code --wait"
      echo "  autocrlf = input"
      echo "[init]"
      echo "  defaultBranch = main"
    } >> "$cfg"
  fi
}

_sr_d3_configure_delta() {
  command -v delta >/dev/null 2>&1 || return 0
  local cfg="$HOME/.gitconfig"
  if ! grep -q "\[delta\]" "$cfg" 2>/dev/null; then
    {
      echo "[delta]"
      echo "  features = decorations"
      echo "  navigate = true"
      echo "[pager]"
      echo "  diff = delta"
      echo "  log  = delta"
      echo "  reflog = delta"
      echo "  show = delta"
      echo "[interactive]"
      echo "  diffFilter = delta --color-only"
      echo "[delta \"decorations\"]"
      echo "  commit-decoration-style = bold yellow box ul"
      echo "  file-style = bold yellow"
      echo "  hunk-header-style = magenta"
    } >> "$cfg"
  fi
}

_sr_d3_offer_precommit_bootstrap() {
  [ -d ".git" ] || return 0
  if sr_confirm "Bootstrap pre-commit for the current repo (.pre-commit-config.yaml)?"; then
    if [ "${DRY_RUN:-0}" = "1" ]; then
      printf "▶️  [dry-run] pre-commit install && pre-commit sample-config > .pre-commit-config.yaml\n"
    else
      pre-commit install || true
      if [ ! -f ".pre-commit-config.yaml" ]; then
        pre-commit sample-config > .pre-commit-config.yaml 2>/dev/null || true
      fi
    fi
  fi
}

sr_domain_03_git() {
  # JSON-driven install
  sr_domain_from_json "$SR_CONF/domains/domain_03_git.json" "${1:-full}"
  # Post-steps
  _sr_d3_seed_gitconfig
  _sr_d3_configure_delta
  _sr_d3_offer_precommit_bootstrap
}
