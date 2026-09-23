#!/usr/bin/env bash
# Run on the development server, passing the checked-in shell files as $1 and $2.
set -euo pipefail
source_file=${1:?Pass the path to shell/asobi.bash}
tmux_source_file=${2:-}
bash -n "$source_file"
if [[ -n "$tmux_source_file" && ! -s "$tmux_source_file" ]]; then
    printf 'Pass a readable file as the second argument for the tmux preferences.\n' >&2
    exit 1
fi
config_dir="$HOME/.config/asobi"
install -d -m 0755 "$config_dir"
backup_dir=$(mktemp -d "$config_dir/backup.XXXXXX")
for config_file in "$HOME/.bashrc" "$config_dir/bashrc" "$HOME/.tmux.conf" "$config_dir/tmux.conf"; do
    if [[ -f "$config_file" ]]; then
        cp -p "$config_file" "$backup_dir/$(basename "$config_file")"
    fi
done
install -m 0644 "$source_file" "$config_dir/bashrc"
source_line='[[ -r ~/.config/asobi/bashrc ]] && source ~/.config/asobi/bashrc'
if ! grep -Fxq "$source_line" "$HOME/.bashrc"; then
    printf '\n# ASOBI interactive shell preferences\n%s\n' "$source_line" >> "$HOME/.bashrc"
fi
# tmux reads the ASOBI preferences through the user's own file, which is kept as it is.
if [[ -n "$tmux_source_file" ]]; then
    install -m 0644 "$tmux_source_file" "$config_dir/tmux.conf"
    touch "$HOME/.tmux.conf"
    tmux_source_line="source-file $config_dir/tmux.conf"
    if ! grep -Fxq "$tmux_source_line" "$HOME/.tmux.conf"; then
        printf '\n# ASOBI tmux preferences\n%s\n' "$tmux_source_line" >> "$HOME/.tmux.conf"
    fi
    if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
        if ! tmux source-file "$config_dir/tmux.conf" >/dev/null 2>&1; then
            printf 'Restart the tmux server to apply the ASOBI tmux preferences.\n'
        fi
    fi
fi
printf 'Installed. Backup: %s\n' "$backup_dir"
