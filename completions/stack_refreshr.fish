# fish completion for stack_refreshr
# Place as: completions/stack_refreshr.fish

complete -c stack_refreshr -s h -l help -d 'Show help'
complete -c stack_refreshr -l dry-run -d 'Preview actions without installing'
complete -c stack_refreshr -l verbose -d 'Show underlying commands'
complete -c stack_refreshr -l sequential -d 'Disable parallel installs'
complete -c stack_refreshr -l enable-telemetry -d 'Enable telemetry for this run'
complete -c stack_refreshr -l telemetry-config -d 'Path to telemetry.json' -r
complete -c stack_refreshr -l set-aliases -d 'Apply recommended aliases'

# subcommands
complete -c stack_refreshr -n "__fish_use_subcommand" -a "telemetry" -d "Telemetry commands"
complete -c stack_refreshr -n "__fish_use_subcommand" -a "aliases" -d "Alias helpers"

# telemetry sub-subcommands
complete -c stack_refreshr -n "__fish_seen_subcommand_from telemetry" -a "explain" -d "Explain collection"
complete -c stack_refreshr -n "__fish_seen_subcommand_from telemetry" -a "show" -d "Show config"
complete -c stack_refreshr -n "__fish_seen_subcommand_from telemetry" -a "dryrun" -d "Simulate send"

# quick keys
for k in 1 2 3 4 5 6 7 8 9 10 11 A Q
  complete -c stack_refreshr -n "__fish_use_subcommand" -a "$k"
end
