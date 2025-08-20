#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s 2>/dev/null || echo unknown)"

ok(){ printf "✅ %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*" >&2; }
have(){ command -v "$1" >/dev/null 2>&1; }

sr_log_json(){
  mkdir -p "$SR_LOGS"
  printf '{"ts":"%s","domain":"%s","tool":"%s","level":"%s","status":"%s"}\n' \
    "$(date -Iseconds)" "$1" "$2" "$3" "$4" >> "$SR_LOGS/install.json"
}

# Ensure a tap exists before installing from it
_sr_ensure_tap() {
  local tap="$1"
  [ -z "$tap" ] && return 0
  brew tap | grep -q "^${tap}\$" || brew tap "$tap" >/dev/null
}

# Return installed tap for a formula, or empty if not installed
_sr_installed_tap() {
  local name="$1"
  local json
  if ! json="$(brew info --json=v2 "$name" 2>/dev/null)"; then
    printf "" && return 0
  fi
  printf '%s\n' "$json" | jq -r '
    .formulae[]?
    | select(.installed | length > 0)
    | .tap // empty
  ' | head -n1
}

# ----- Shell integration helpers --------------------------------------------
_sr_rc_file() {
  if [ -n "${ZDOTDIR:-}" ] && [ -f "$ZDOTDIR/.zshrc" ]; then
    printf "%s\n" "$ZDOTDIR/.zshrc"; return
  fi
  if [ -f "$HOME/.zshrc" ]; then
    printf "%s\n" "$HOME/.zshrc"; return
  fi
  if [ -f "$HOME/.bashrc" ]; then
    printf "%s\n" "$HOME/.bashrc"; return
  fi
  printf "%s\n" "$HOME/.zshrc"
}

_sr_append_once() {
  local rc="$1" line="$2"
  grep -Fqx "$line" "$rc" 2>/dev/null || printf "%s\n" "$line" >> "$rc"
}

_sr_sed_inplace() {
  local expr="$1" file="$2"
  if [ "$OS" = "Darwin" ]; then
    sed -i '' -e "$expr" "$file"
  else
    sed -i -e "$expr" "$file"
  fi
}

_sr_install_ohmyzsh() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || return 1
    ok "oh-my-zsh installed"
  fi
}

_sr_repo_root() {
  local here
  here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  cd "$here/.." && pwd
}

_sr_setup_p10k() {
  local rc root tpl1 tpl2
  rc="$(_sr_rc_file)"
  have zsh || brew install zsh >/dev/null 2>&1 || true
  _sr_install_ohmyzsh || warn "oh-my-zsh install skipped or failed"

  local omz_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local p10k_dir="$omz_custom/themes/powerlevel10k"
  if [ ! -d "$p10k_dir" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" >/dev/null 2>&1 || true
  fi

  if [ -f "$rc" ]; then
    if grep -q '^ZSH_THEME=' "$rc"; then
      _sr_sed_inplace 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$rc"
    else
      printf '%s\n' 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$rc"
    fi
  else
    printf '%s\n' 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$rc"
  fi

  root="$(_sr_repo_root)"
  tpl1="$root/configuration/.p10k.zsh"
  tpl2="$root/templates/p10k_mysetup.zsh"
  if [ -f "$tpl1" ]; then
    cp "$tpl1" "$HOME/.p10k.zsh"
    ok "Applied repo p10k config from configuration/.p10k.zsh"
  elif [ -f "$tpl2" ]; then
    cp "$tpl2" "$HOME/.p10k.zsh"
    ok "Applied repo p10k config from templates/p10k_mysetup.zsh"
  fi

  _sr_append_once "$rc" '[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh'
  ok "powerlevel10k wired into $(basename "$rc")"
}

_sr_post_install_integration() {
  local tool rc
  tool="$1"
  rc="$(_sr_rc_file)"

  case "$tool" in
    thefuck)
      _sr_append_once "$rc" 'eval $(thefuck --alias)'
      eval "$(thefuck --alias)" || true
      ok "thefuck alias added to $(basename "$rc")"
      printf "💡 Tip: run a failing command, then type 'fuck' to fix and re-run.\n"
      ;;
    zoxide)
      if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
        _sr_append_once "$rc" 'eval "$(zoxide init zsh)"'
      else
        _sr_append_once "$rc" 'eval "$(zoxide init bash)"'
      fi
      ok "zoxide init added to $(basename "$rc")"
      ;;
    starship)
      if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
        _sr_append_once "$rc" 'eval "$(starship init zsh)"'
      else
        _sr_append_once "$rc" 'eval "$(starship init bash)"'
      fi
      ok "starship init added to $(basename "$rc")"
      ;;
    atuin)
      if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
        _sr_append_once "$rc" 'eval "$(atuin init zsh)"'
      else
        _sr_append_once "$rc" 'eval "$(atuin init bash)"'
      fi
      ok "atuin init added to $(basename "$rc")"
      ;;
    zsh-autosuggestions)
      if [ -d "/opt/homebrew/share/zsh-autosuggestions" ]; then
        _sr_append_once "$rc" 'source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh'
      elif [ -d "/usr/share/zsh-autosuggestions" ]; then
        _sr_append_once "$rc" 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh'
      fi
      ok "zsh-autosuggestions sourced in $(basename "$rc")"
      ;;
    zsh-syntax-highlighting)
      if [ -d "/opt/homebrew/share/zsh-syntax-highlighting" ]; then
        _sr_append_once "$rc" 'source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
      elif [ -d "/usr/share/zsh-syntax-highlighting" ]; then
        _sr_append_once "$rc" 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
      fi
      ok "zsh-syntax-highlighting sourced in $(basename "$rc")"
      ;;
    powerlevel10k)
      _sr_setup_p10k
      ;;
  esac
}

# --- Webinstall wrapper ------------------------------------------------------
sr_webi_install() {
  local tool="$1"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    ok "[dry-run] webi $tool"
    return 0
  fi

  if have "$tool"; then
    ok "$tool (already installed)"
    return 0
  fi

  if ! curl -sS "https://webi.sh/${tool}" | sh; then
    warn "webi install failed for $tool"
    return 1
  fi

  [ -f "$HOME/.config/envman/PATH.env" ] && . "$HOME/.config/envman/PATH.env" || true

  if have "$tool"; then
    ok "$tool (installed via webinstall)"
  else
    warn "$tool not found after webi install"
    return 1
  fi
}

# --- Brew install wrapper ----------------------------------------------------
sr_brew_install() {
  local fqname="$1" type="$2"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    ok "[dry-run] brew install $fqname ($type)"
    return 0
  fi

  local tap="" name="$fqname"
  if [[ "$fqname" == */*/* ]]; then
    tap="${fqname%/*}"
    name="${fqname##*/}"
  fi

  local installed_tap; installed_tap="$(_sr_installed_tap "$name")"
  if [ -n "$installed_tap" ]; then
    if [ "$type" = "cask" ]; then
      brew upgrade --cask "${installed_tap:+$installed_tap/}$name" >/dev/null || true
    else
      brew upgrade "${installed_tap:+$installed_tap/}$name" >/dev/null || true
    fi
    ok "$name (already installed via $installed_tap)"
    return 0
  fi

  [ -n "$tap" ] && _sr_ensure_tap "$tap"

  if [ "$type" = "cask" ]; then
    brew install --cask "$fqname" >/dev/null
  else
    brew install "$fqname" >/dev/null
  fi
}

# --- Tool mapper -------------------------------------------------------------
sr_tool_brew_tuple() {
  case "$1" in
    # casks
    raycast|warp|visual-studio-code|vscode) echo "visual-studio-code cask" ;;

    # Domain 1 — Terminal & UX
    eza) echo "eza formula" ;;
    fzf) echo "fzf formula" ;;
    bat) echo "bat formula" ;;
    ripgrep|rg) echo "ripgrep formula" ;;
    zsh) echo "zsh formula" ;;
    tmux) echo "tmux formula" ;;
    powerlevel10k) echo "powerlevel10k formula" ;;
    fd) echo "fd formula" ;;
    zoxide) echo "zoxide formula" ;;
    atuin) echo "atuin formula" ;;
    gum) echo "gum formula" ;;
    figlet) echo "figlet formula" ;;
    lolcat) echo "lolcat formula" ;;
    dust) echo "dust formula" ;;
    procs) echo "procs formula" ;;
    starship) echo "starship formula" ;;
    zsh-autosuggestions) echo "zsh-autosuggestions formula" ;;
    zsh-syntax-highlighting) echo "zsh-syntax-highlighting formula" ;;
    tldr) echo "tldr formula" ;;
    thefuck) echo "thefuck formula" ;;

    # Domain 2 — SSH & Key Management
    openssh) echo "openssh formula" ;;
    ssh-audit) echo "ssh-audit formula" ;;
    age) echo "age formula" ;;
    gh|gh-key-upload) echo "gh formula" ;;

    # Domain 3 — Git & Source Control
    git) echo "git formula" ;;
    pre-commit) echo "pre-commit formula" ;;
    delta) echo "git-delta formula" ;;
    lazygit) echo "lazygit formula" ;;
    gitleaks) echo "gitleaks formula" ;;
    git-secrets) echo "git-secrets formula" ;;
    git-cliff) echo "git-cliff formula" ;;
    gpg|gnupg) echo "gnupg formula" ;;

    # Domain 4 — Code & Dev Tools
    just) echo "just formula" ;;
    direnv) echo "direnv formula" ;;
    shellcheck) echo "shellcheck formula" ;;
    prettier) echo "prettier formula" ;;
    asdf) echo "asdf formula" ;;
    shfmt) echo "shfmt formula" ;;
    eslint) echo "eslint formula" ;;
    black) echo "black formula" ;;
    hadolint) echo "hadolint formula" ;;
    nvm) echo "nvm formula" ;;
    pyenv) echo "pyenv formula" ;;
    mise) echo "mise formula" ;;
    commitizen) echo "commitizen formula" ;;
    lefthook) echo "lefthook formula" ;;
    vscode) echo "visual-studio-code cask" ;;

    # Domain 5 — Containers & Runtimes
    colima)            echo "colima formula" ;;
    docker)            echo "docker formula" ;;
    podman)            echo "podman formula" ;;
    compose|docker-compose) echo "docker-compose formula" ;;
    nomad)             echo "hashicorp/tap/nomad formula" ;;
    buildah)           echo "buildah formula" ;;
    skopeo)            echo "skopeo formula" ;;
    trivy)             echo "trivy formula" ;;
    ctop)              echo "ctop formula" ;;
    dive)              echo "dive formula" ;;
    docker-slim|dockerslim) echo "docker-slim formula" ;;
    syft)              echo "syft formula" ;;
    grype)             echo "grype formula" ;;

    # Domain 6 — Kubernetes (Local Dev)
    kubectl)           echo "kubectl formula" ;;
    helm)              echo "helm formula" ;;
    k9s)               echo "k9s formula" ;;
    stern)             echo "stern formula" ;;
    kubectx)           echo "kubectx formula" ;;
    kubens)            echo "kubens webi" ;;
    k3d)               echo "k3d formula" ;;
    kind)              echo "kind formula" ;;

    # Domain 7 — Secrets & Certs
    vault)             echo "hashicorp/tap/vault formula" ;;
    sops)              echo "sops formula" ;;
    mkcert)            echo "mkcert formula" ;;
    "1password-cli"|op) echo "1password-cli formula" ;;
    boundary)          echo "hashicorp/tap/boundary formula" ;;

    # Domain 8 — Observability & Logs
    jq)                echo "jq formula" ;;
    yq)                echo "yq formula" ;;
    bottom|btm)        echo "bottom formula" ;;
    btop)              echo "btop formula" ;;
    htop)              echo "htop formula" ;;
    lnav)              echo "lnav formula" ;;
    fx)                echo "fx formula" ;;
    glow)              echo "glow formula" ;;
    logrotate)         echo "logrotate formula" ;;
    viddy)             echo "viddy formula" ;;
    gping)             echo "gping formula" ;;
    duf)               echo "duf formula" ;;
    httpie)            echo "httpie formula" ;;
    ncdu)              echo "ncdu formula" ;;
    neofetch)          echo "neofetch formula" ;;

    # Domain 9 — Infrastructure as Code
    terraform)         echo "hashicorp/tap/terraform formula" ;;
    tflint)            echo "tflint formula" ;;
    tfsec)             echo "tfsec formula" ;;
    checkov)           echo "checkov formula" ;;
    terragrunt)        echo "terragrunt formula" ;;
    packer)            echo "hashicorp/tap/packer formula" ;;
    terraform-docs)    echo "terraform-docs formula" ;;
    tfenv)             echo "tfenv formula" ;;
    consul)            echo "hashicorp/tap/consul formula" ;;
    awscli)            echo "awscli formula" ;;

    # Domain 10 — Automation & Scheduling
    parallel)          echo "parallel formula" ;;
    watchexec)         echo "watchexec formula" ;;
    entr)              echo "entr formula" ;;
    hyperfine)         echo "hyperfine formula" ;;
    tmuxinator)        echo "tmuxinator formula" ;;
    cron)              echo "cron formula" ;;
    at)                echo "at formula" ;;
    tmux-resurrect)    echo "tmux-resurrect formula" ;;

    # Networking & API extras if you add them to JSON
    curlie)            echo "curlie formula" ;;
    nmap)              echo "nmap formula" ;;
    dig)               echo "bind formula" ;;
    the_silver_searcher|ag) echo "the_silver_searcher formula" ;;
    tree)              echo "tree formula" ;;

    # default
    *) echo "$1 formula" ;;
  esac
}

# helper to check if brew has a specific formula installed
_sr_brew_has_pkg() {
  local name="$1"
  brew list --formula | grep -qx "$name"
}

sr_install_tool() {
  local domain="$1" tool="$2" level="$3"
  read -r brew_name brew_type < <(sr_tool_brew_tuple "$tool")
  if [ -z "${brew_name:-}" ]; then brew_name="$tool"; fi

  # Friendly messages for kubectx/kubens already present
  if [ "$tool" = "kubectx" ] && have kubectx; then
    local tap; tap="$(_sr_installed_tap kubectx)"
    sr_log_json "$domain" "$tool" "$level" "installed"
    ok "kubectx (already installed${tap:+ via $tap})"
    sr_record_tool_version "$tool" "$brew_name" "$brew_type" "$domain" || true
    return 0
  fi
  if [ "$tool" = "kubens" ] && have kubens; then
    if have brew && _sr_brew_has_pkg kubectx; then
      local tap; tap="$(_sr_installed_tap kubectx)"
      sr_log_json "$domain" "$tool" "$level" "installed"
      ok "kubens (already installed via ${tap:-homebrew/core}, provided by kubectx)"
      sr_record_tool_version "$tool" "$brew_name" "$brew_type" "$domain" || true
      return 0
    fi
    sr_log_json "$domain" "$tool" "$level" "installed"
    ok "kubens (already installed)"
    sr_record_tool_version "$tool" "$brew_name" "$brew_type" "$domain" || true
    return 0
  fi

  # If tool already exists on PATH, mark installed and still do post-integration
  if have "$tool"; then
    sr_log_json "$domain" "$tool" "$level" "installed"
    ok "$tool (already installed)"
    case "$tool" in
      thefuck|zoxide|starship|atuin|zsh-autosuggestions|zsh-syntax-highlighting|powerlevel10k)
        _sr_post_install_integration "$tool"
        ;;
    esac
    sr_record_tool_version "$tool" "$brew_name" "$brew_type" "$domain" || true
    return 0
  fi

  case "$brew_type" in
    webi)
      if ! sr_webi_install "$brew_name"; then
        sr_log_json "$domain" "$tool" "$level" "failed"
        return 1
      fi
      ;;
    cask|formula|*)
      if have brew; then
        if ! sr_brew_install "$brew_name" "$brew_type"; then
          sr_log_json "$domain" "$tool" "$level" "failed"
          return 1
        fi
        # Optionally upgrade if outdated (formulas only)
        if [ "$brew_type" != "cask" ]; then
          sr_brew_maybe_upgrade "$brew_name" || true
        fi
      else
        warn "brew not found; skipping install of $tool (mock)"
      fi
      ;;
  esac

  sr_log_json "$domain" "$tool" "$level" "installed"
  ok "$tool ($level)"

  # Post-install shell wiring where needed
  case "$tool" in
    thefuck|zoxide|starship|atuin|zsh-autosuggestions|zsh-syntax-highlighting|powerlevel10k)
      _sr_post_install_integration "$tool"
      ;;
  esac

  # Record version/state after install/upgrade
  sr_record_tool_version "$tool" "$brew_name" "$brew_type" "$domain" || true
}

sr_install_group() {
  local domain="$1" level="$2"; shift 2
  local tools=("$@")
  for t in "${tools[@]}"; do sr_install_tool "$domain" "$t" "$level"; done
}

sr_install_all_must() {
  ok "Installing ALL MUST tools from implemented domains…"
  for fn in \
    sr_domain_01_terminal sr_domain_02_ssh sr_domain_03_git sr_domain_04_code \
    sr_domain_05_containers sr_domain_06_k8s sr_domain_07_secrets \
    sr_domain_08_observability sr_domain_09_iac sr_domain_10_automation
  do
    sr_run_or_warn "$fn" must-only
  done
  ok "All MUST done"
}
