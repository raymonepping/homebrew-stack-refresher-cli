#!/usr/bin/env bash
set -euo pipefail

have(){ command -v "$1" >/dev/null 2>&1; }

sr_install_shell_completions() {
  local src="$SR_ROOT/completions"
  [ -d "$src" ] || return 0

  if have brew; then
    local prefix; prefix="$(brew --prefix)"

    # Bash
    if [ -f "$src/stack_refreshr.bash" ]; then
      install -d "$prefix/share/bash-completion/completions"
      install -m 0644 "$src/stack_refreshr.bash" "$prefix/share/bash-completion/completions/stack_refreshr"
    fi

    # Zsh
    if [ -f "$src/_stack_refreshr" ]; then
      install -d "$prefix/share/zsh/site-functions"
      install -m 0644 "$src/_stack_refreshr" "$prefix/share/zsh/site-functions/_stack_refreshr"
    fi

    # Fish
    if [ -f "$src/stack_refreshr.fish" ]; then
      install -d "$prefix/share/fish/vendor_completions.d"
      install -m 0644 "$src/stack_refreshr.fish" "$prefix/share/fish/vendor_completions.d/stack_refreshr.fish"
    fi
  fi
}
