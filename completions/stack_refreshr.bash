# bash completion for stack_refreshr
# Place as: completions/stack_refreshr.bash

_stack_refreshr()
{
  local cur prev words cword
  COMPREPLY=()
  _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null || {
    # fallback when bash-completion isn't present
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
  }

  # Global flags
  local gflags="--help --dry-run --verbose --sequential --enable-telemetry --telemetry-config --set-aliases"
  # Top-level subcommands (non-interactive helpers)
  local subs="telemetry aliases"

  # Dynamic domain choices (numbers + pretty names)
  local domains="1 2 3 4 5 6 7 8 9 10 11 A Q"

  # If completing after 'telemetry'
  if [[ ${words[1]} == "telemetry" ]]; then
    local tsubs="explain show dryrun"
    COMPREPLY=( $(compgen -W "${tsubs}" -- "$cur") )
    return 0
  fi

  # If completing after 'aliases'
  if [[ ${words[1]} == "aliases" ]]; then
    local asubs="restore status --json"
    COMPREPLY=( $(compgen -W "${asubs}" -- "$cur") )
    return 0
  fi

  # Complete flag values
  case "$prev" in
    --telemetry-config)
      # file path
      COMPREPLY=( $(compgen -f -- "$cur") )
      return 0
      ;;
  esac

  # Offer flags, subcommands, and quick-select keys
  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "${gflags}" -- "$cur") )
  else
    COMPREPLY=( $(compgen -W "${subs} ${domains}" -- "$cur") )
  fi
}

# Register
complete -F _stack_refreshr stack_refreshr
