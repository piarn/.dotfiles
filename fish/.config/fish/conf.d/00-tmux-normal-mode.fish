# Belt-and-suspenders for tmux/.config/tmux/tmux.conf's client-attached hook:
# ensure the client is in vim-normal mode as soon as an interactive shell
# starts inside tmux. Runs from a fully-attached client, so it can't race
# tmux's own attach-completion the way the hook occasionally can.
if status is-interactive; and set -q TMUX
    tmux switch-client -T vim-normal
end
