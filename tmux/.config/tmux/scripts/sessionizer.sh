#!/usr/bin/env bash
# tmux session manager: fzf-pick an existing tmux session, or a project
# directory under ~/projects (plus ~/.dots), and switch to it — creating a
# new session from the directory's basename if one doesn't exist yet.
#
# Meant to run inside a tmux popup (bound to leader+S in vim-modes.conf), so
# it can end with `tmux switch-client` and have that land on the real client.
set -euo pipefail

projects=$(
    {
        find "$HOME/projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
        printf '%s\n' "$HOME/.dots"
    } | sort -u
)
sessions=$(tmux list-sessions -F '#S' 2>/dev/null || true)

selection=$(
    {
        printf '%s\n' "$sessions" | sed '/^$/d;s/^/[session]\t/'
        printf '%s\n' "$projects" | sed '/^$/d;s/^/[project]\t/'
    } | fzf --delimiter='\t' --with-nth=2 --prompt='session/project> '
) || exit 0

[ -z "$selection" ] && exit 0

kind=${selection%%$'\t'*}
target=${selection#*$'\t'}

if [ "$kind" = "[session]" ]; then
    session_name="$target"
else
    session_name=$(basename "$target" | tr '.:' '__')
    tmux has-session -t "$session_name" 2>/dev/null ||
        tmux new-session -ds "$session_name" -c "$target"
fi

tmux switch-client -t "$session_name"
