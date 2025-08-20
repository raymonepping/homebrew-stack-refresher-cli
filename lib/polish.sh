#!/usr/bin/env bash
# Lightweight "polish mode" helpers — all optional.

have(){ command -v "$1" >/dev/null 2>&1; }

# Detect glam
export SR_POLISH=0
if have lolcat || have figlet || have toilet || have cowsay || have glow || have boxes || have neofetch; then
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

# Optional system summary
polish_sysinfo() {
  if have fastfetch; then fastfetch | polish_colorize
  elif have neofetch; then neofetch | polish_colorize
  fi
}
