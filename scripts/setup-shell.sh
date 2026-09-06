#!/usr/bin/env bash
# Run on the development server, passing the checked-in shell file as $1.
set -euo pipefail
source_file=${1:?Pass the path to shell/asobi.bash}
bash -n "$source_file"
config_dir="$HOME/.config/asobi"
install -d -m 0755 "$config_dir"
backup_dir=$(mktemp -d "$config_dir/backup.XXXXXX")
for config_file in "$HOME/.bashrc" "$config_dir/bashrc"; do
    if [[ -f "$config_file" ]]; then
        cp -p "$config_file" "$backup_dir/$(basename "$config_file")"
    fi
done
install -m 0644 "$source_file" "$config_dir/bashrc"
source_line='[[ -r ~/.config/asobi/bashrc ]] && source ~/.config/asobi/bashrc'
if ! grep -Fxq "$source_line" "$HOME/.bashrc"; then
    printf '\n# ASOBI interactive shell preferences\n%s\n' "$source_line" >> "$HOME/.bashrc"
fi
printf 'Installed. Backup: %s\n' "$backup_dir"
