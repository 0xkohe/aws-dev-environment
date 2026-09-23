#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d /tmp/asobi-shell-tests.XXXXXX)
export PATH="$repo/tests/mock-bin:$PATH"
export ASOBI_TEST_LOG="$scratch/tmux.log"
home="$scratch/home"
install -d -m 0700 "$home"
: > "$home/.bashrc"
printf '%s\n' 'set -g status-bg blue' > "$home/.tmux.conf"

: > "$ASOBI_TEST_LOG"
HOME="$home" bash "$repo/scripts/setup-shell.sh" "$repo/shell/asobi.bash" "$repo/shell/asobi.tmux.conf"
grep -Fxq 'set -g mouse on' "$home/.config/asobi/tmux.conf"
grep -Fxq "source-file $home/.config/asobi/tmux.conf" "$home/.tmux.conf"
grep -Fxq 'set -g status-bg blue' "$home/.tmux.conf"
grep -Fxq '[[ -r ~/.config/asobi/bashrc ]] && source ~/.config/asobi/bashrc' "$home/.bashrc"
grep -Fq "source-file $home/.config/asobi/tmux.conf" "$ASOBI_TEST_LOG"
printf 'PASS: setup installs the default tmux mouse setting and reloads the running server\n'

# A repeated run must not append the source lines twice, and it must keep the previous files.
HOME="$home" bash "$repo/scripts/setup-shell.sh" "$repo/shell/asobi.bash" "$repo/shell/asobi.tmux.conf"
[[ $(grep -c 'source-file ' "$home/.tmux.conf") == 1 ]]
[[ $(grep -c 'asobi/bashrc' "$home/.bashrc") == 1 ]]
backup=$(find "$home/.config/asobi" -maxdepth 1 -type d -name 'backup.*' | sort | tail -n 1)
test -f "$backup/.tmux.conf"
grep -Fxq 'set -g status-bg blue' "$backup/.tmux.conf"
printf 'PASS: a repeated setup keeps single source lines and backs up the user tmux file\n'

# The second argument is optional, so an existing installation keeps working.
plain_home="$scratch/plain"
install -d -m 0700 "$plain_home"
: > "$plain_home/.bashrc"
HOME="$plain_home" bash "$repo/scripts/setup-shell.sh" "$repo/shell/asobi.bash"
test -s "$plain_home/.config/asobi/bashrc"
test ! -e "$plain_home/.tmux.conf"
printf 'PASS: the tmux argument is optional\n'
