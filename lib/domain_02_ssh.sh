#!/usr/bin/env bash
set -euo pipefail

# post-steps unique to SSH domain
_sr_d2_seed_config() {
  local cfg="$HOME/.ssh/config"
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  if [ ! -f "$cfg" ]; then
    cat > "$cfg" <<'CFG'
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60
  ServerAliveCountMax 3
CFG
    chmod 600 "$cfg"
  fi
}

_sr_d2_generate_ed25519() {
  [ -f "$HOME/.ssh/id_ed25519" ] && return 0
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf "▶️  [dry-run] ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -C '%s@%s'\n" "$(whoami)" "$(hostname)"
    return 0
  fi
  ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "$(whoami)@$(hostname)"
}

sr_domain_02_ssh() {
  # Run the JSON-driven flow
  sr_domain_from_json "$SR_CONF/domains/domain_02_ssh.json" "${1:-full}"
  # Then do SSH-specific seeding (idempotent)
  _sr_d2_seed_config
  _sr_d2_generate_ed25519
}
