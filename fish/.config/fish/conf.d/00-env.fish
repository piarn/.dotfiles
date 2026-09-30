set -gx EDITOR nvim
set -gx VISUAL nvim

set -gx RIPGREP_CONFIG_PATH ~/.config/ripgrep/config

# The session agent (ssh-agent.service); environment.d normally sets this
# already, this covers a shell that didn't come from the systemd session
# (a tty login). A forwarded agent over ssh is left alone.
set -q SSH_AUTH_SOCK; or set -gx SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket
