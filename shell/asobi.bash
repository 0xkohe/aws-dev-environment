# Interactive Bash preferences for the ASOBI development host.
[[ $- == *i* ]] || return
[[ ${ASOBI_BASH_LOADED:-} == 1 ]] && return
ASOBI_BASH_LOADED=1

HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth
HISTTIMEFORMAT='%F %T '
shopt -s histappend checkwinsize

# Append this terminal's new commands before reading other terminals' history.
asobi_history_sync() { history -a; history -n; }
if declare -p PROMPT_COMMAND 2>/dev/null | grep -q 'declare -a'; then
    PROMPT_COMMAND+=(asobi_history_sync)
else
    PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND}; }asobi_history_sync"
fi

bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set colored-stats on'
bind 'set mark-symlinked-directories on'
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

if [[ -r /usr/lib/git-core/git-sh-prompt ]]; then
    source /usr/lib/git-core/git-sh-prompt
fi
if declare -F __git_ps1 >/dev/null; then
    PS1='\[\e[1;32m\]\u@\h\[\e[0m\] \[\e[1;34m\]\w\[\e[33m\]$(__git_ps1 " (%s)")\[\e[0m\]\n\$ '
else
    PS1='\[\e[1;32m\]\u@\h\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\]\n\$ '
fi
