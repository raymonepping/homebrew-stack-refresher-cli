#!/usr/bin/env bash
set -euo pipefail

# Seed VS Code settings.json with sane defaults
_sr_d4_seed_vscode_settings() {
  local cfg="$HOME/Library/Application Support/Code/User/settings.json"
  mkdir -p "$(dirname "$cfg")"
  if [ ! -f "$cfg" ]; then
    cat > "$cfg" <<'JSON'
{
  "editor.formatOnSave": true,
  "editor.tabSize": 2,
  "files.autoSave": "onFocusChange"
}
JSON
  fi
}

# Install VS Code extensions if available
_sr_d4_install_vscode_extensions() {
  command -v code >/dev/null 2>&1 || return 0
  local extensions=(
    ms-azuretools.vscode-docker
    hashicorp.terraform
    ms-vscode-remote.remote-ssh
    ms-vscode-remote.remote-containers
  )
  for ext in "${extensions[@]}"; do
    if [ "${DRY_RUN:-0}" = "1" ]; then
      printf "▶️  [dry-run] code --install-extension %s\n" "$ext"
    else
      code --install-extension "$ext" >/dev/null 2>&1 || true
    fi
  done
}

# Initialize direnv if available
_sr_d4_setup_direnv() {
  command -v direnv >/dev/null 2>&1 || return 0
  local bashrc="$HOME/.bashrc"
  if ! grep -q 'eval "$(direnv hook bash)"' "$bashrc" 2>/dev/null; then
    echo 'eval "$(direnv hook bash)"' >> "$bashrc"
  fi
}

sr_domain_04_code() {
  # JSON-driven install
  sr_domain_from_json "$SR_CONF/domains/domain_04_code.json" "${1:-full}"
  # Post-steps
  _sr_d4_seed_vscode_settings
  _sr_d4_install_vscode_extensions
  _sr_d4_setup_direnv
}
