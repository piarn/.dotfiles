#!/usr/bin/env bash
# Open the URL under the mouse. Called from the Ctrl+click binds in tmux.conf:
#   open-url.sh hHYPERLINK lLINE xX
# (each arg carries a one-letter prefix so an empty value can't drop out of the
# argument list.) HYPERLINK is #{mouse_hyperlink} (OSC 8 links), LINE the text of the clicked
# row and X the clicked column; plain-text URLs are found in LINE around X.
#
# Opens with ~/.local/bin/browser (machine-local Firefox launcher: snap /
# flatpak / native) if present, else xdg-open.
# tmux's #{q:} backslash-escapes shell metacharacters; the shell strips them
url=${1#h} line=${2#l} x=${3#x}

if [ -z "$url" ]; then
    url=$(python3 - "$line" "$x" <<'PY'
import re, sys
line, x = sys.argv[1], int(sys.argv[2] or 0)
for m in re.finditer(r'''(?:https?|ftp|file)://[^\s<>"'`]+''', line):
    u = m.group(0)
    # trailing sentence punctuation, and a closing bracket with no opener
    while u and (u[-1] in '.,;:!?\'"' or (u[-1] in ')]}' and u.count({')':'(',']':'[','}':'{'}[u[-1]]) < u.count(u[-1]))):
        u = u[:-1]
    if m.start() <= x < m.start() + len(u):
        print(u)
        break
PY
)
fi

if [ -z "$url" ]; then
    tmux display-message "no URL under the pointer"
    exit 0
fi

# the tmux server can be older than the desktop session, so its own
# environment may miss the display; pull it from the client's
for v in WAYLAND_DISPLAY DISPLAY SWAYSOCK XDG_RUNTIME_DIR; do
    [ -n "${!v:-}" ] || { val=$(tmux show-environment -g "$v" 2>/dev/null | sed -n "s/^$v=//p"); [ -z "$val" ] || export "$v=$val"; }
done

if [ -x "$HOME/.local/bin/browser" ]; then opener="$HOME/.local/bin/browser"; else opener=xdg-open; fi
tmux display-message "opening $url"
setsid -f "$opener" "$url" >/dev/null 2>&1
