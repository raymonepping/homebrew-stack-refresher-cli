#!/usr/bin/env bash
# Lightweight "polish mode" helpers — all optional.

# Local utility (safe to redefine here)
have(){ command -v "$1" >/dev/null 2>&1; }

# Feature flags (defaults)
: "${SR_SHOW_SYSTEM:=0}"   # OFF by default; set to 1 or use --show-system to enable
export SR_SHOW_SYSTEM

# Detect glam-capable environment (cosmetic only)
export SR_POLISH=0
if have lolcat || have figlet || have toilet || have cowsay || have glow || have boxes || have neofetch || have fastfetch; then
  SR_POLISH=1
fi

# Colorize (only if lolcat exists and we’re on a TTY)
polish_colorize() {
  if have lolcat && [ -t 1 ]; then
    lolcat
  else
    cat
  fi
}

# Big banners (figlet/toilet -> lolcat)
polish_banner() {
  local msg="$*"
  if have figlet; then
    figlet -w 120 "$msg" | polish_colorize
  elif have toilet; then
    toilet -w 120 -f big "$msg" | polish_colorize
  else
    printf "=== %s ===\n" "$msg" | polish_colorize
  fi
}

# Cute callouts (cowsay if present)
polish_say() {
  local msg="$*"
  if have cowsay; then
    cowsay -f tux "$msg" | polish_colorize
  else
    printf "%s\n" "$msg" | polish_colorize
  fi
}

# Box wrapper for multi-line text (boxes if present)
polish_box() {
  if have boxes; then
    boxes -d round
  else
    cat
  fi
}

# Optional system summary (guarded by SR_SHOW_SYSTEM; outputs via say)
polish_sysinfo() {
  [ "${SR_SHOW_SYSTEM:-0}" = "1" ] || return 0

  # Prefer fastfetch, then neofetch; pipe through colorizer; emit via say()
  if have fastfetch; then
    # Try nicer small logo first, fall back if unsupported
    if fastfetch --logo small --pipe >/dev/null 2>&1; then
      fastfetch --logo small --pipe | polish_colorize | while IFS= read -r l; do say "$l"; done
    else
      fastfetch | polish_colorize | while IFS= read -r l; do say "$l"; done
    fi
  elif have neofetch; then
    neofetch 2>/dev/null | polish_colorize | while IFS= read -r l; do say "$l"; done
  fi
}
