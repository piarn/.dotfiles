#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"

stub swaymsg 'echo "swaymsg SWAYSOCK=$SWAYSOCK $*" >>"$CALLS"'
stub pkill 'echo "pkill $*" >>"$CALLS"'
R=$BIN/dots-rescue
export DOTS_RESCUE_RUNDIR=$TMP/run QS_GOOD=$TMP/good
mkdir -p "$DOTS_RESCUE_RUNDIR" "$QS_GOOD"
touch "$QS_GOOD/shell.qml"

# a live "sway" (a real process) with an older socket, a dead one newer
sleep 30 & live=$!
touch -d '-2 min' "$DOTS_RESCUE_RUNDIR/sway-ipc.$(id -u).$live.sock"
# sorts before any live pid, so the glob reaches it first
touch "$DOTS_RESCUE_RUNDIR/sway-ipc.$(id -u).0999999.sock"

"$R" sway-reload
check "stale sockets skipped: the live sway's used" called "SWAYSOCK=$DOTS_RESCUE_RUNDIR/sway-ipc.$(id -u).$live.sock reload"

: >"$CALLS"; "$R" quickshell-good >/dev/null
check "quickshell-good: old instance killed" called "pkill -KILL -x quickshell"
check "quickshell-good: snapshot started" called "-p $QS_GOOD"

: >"$CALLS"; "$R" lock-prompt >/dev/null
check "lock-prompt: swaylock started in the session" called "exec swaylock -f"

# revert stashes (not discards) uncommitted quickshell/ changes
export DOTS_DIR=$TMP/dots
git init -q "$DOTS_DIR"; mkdir -p "$DOTS_DIR/quickshell"
echo committed >"$DOTS_DIR/quickshell/f"
git -C "$DOTS_DIR" add -A; git -C "$DOTS_DIR" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm init
echo broken >"$DOTS_DIR/quickshell/f"
: >"$CALLS"; "$R" quickshell-revert >/dev/null
check "revert: working tree back to committed" [ "$(cat "$DOTS_DIR/quickshell/f")" = committed ]
stashed() { git -C "$DOTS_DIR" stash list --format=%s | grep -q "dots-rescue"; }
check "revert: change kept in a stash" stashed
check "revert: quickshell restarted" called "pkill -KILL -x quickshell"

"$R" >/dev/null 2>&1
check "no subcommand: usage, non-zero" [ $? != 0 ]

kill "$live"
rm "$DOTS_RESCUE_RUNDIR"/sway-ipc.*
"$R" sway-reload >/dev/null 2>&1
check "no sway running: fails" [ $? != 0 ]

finish
