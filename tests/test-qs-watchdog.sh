#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"

stub swaymsg 'echo "swaymsg $*" >>"$CALLS"'
stub logger ':'
export QS_RUN=$TMP/run QS_GOOD=$TMP/good QS_LIVE=$TMP/live
QS_WATCHDOG_LIB=1 . "$BIN/qs-watchdog"

# a live config whose files are symlinks, like stow's
mkdir -p "$TMP/src" "$QS_LIVE/popups"
echo "shell v1" >"$TMP/src/shell.qml"
ln -s "$TMP/src/shell.qml" "$QS_LIVE/shell.qml"
echo "popup" >"$QS_LIVE/popups/P.qml"

# fake instances: real processes (so kill works), with logs like quickshell's
# output redirected, or $(spawn) would wait for the background sleep
# `; :` stops sh from exec'ing sleep, which would drop these args from
# /proc/<pid>/cmdline, where is_fallback looks
spawn() { sh -c 'sleep 30; :' "$@" >/dev/null 2>&1 & echo $!; }
log() { mkdir -p "$QS_RUN/quickshell/by-pid/$1"; echo "$2" >"$QS_RUN/quickshell/by-pid/$1/log.log"; }
alive() { kill -0 "$1" 2>/dev/null; }
dead() { ! alive "$1"; }

p=$(spawn x); log "$p" "INFO: Configuration Loaded"
check "config_state loaded" [ "$(config_state "$p")" = loaded ]
log "$p" "ERROR: Failed to load configuration"
check "config_state failed" [ "$(config_state "$p")" = failed ]
log "$p" "INFO: Launching config"
check "config_state pending" [ "$(config_state "$p")" = pending ]
f=$(spawn x -p "$QS_GOOD")
check "is_fallback: snapshot instance" is_fallback "$f"
check "is_fallback: live instance" not is_fallback "$p"
kill "$p" "$f"

snapshot
check "snapshot copies file contents" [ "$(cat "$QS_GOOD/shell.qml")" = "shell v1" ]
check "snapshot resolves symlinks" [ ! -L "$QS_GOOD/shell.qml" ]
check "snapshot copies subdirectories" [ -f "$QS_GOOD/popups/P.qml" ]
echo "shell v2" >"$TMP/src/shell.qml"; snapshot
check "snapshot refreshes on change" [ "$(cat "$QS_GOOD/shell.qml")" = "shell v2" ]

# failed config, snapshot present: killed, snapshot started, nag shown
: >"$CALLS"; checked=""
p=$(spawn x); log "$p" "ERROR: Failed to load configuration"
list_instances() { echo "$p"; }
check_configs; sleep 0.2
check "failed: instance killed" dead "$p"
check "failed: snapshot started" called "-p $QS_GOOD"
check "failed: user told" called "swaynag"

# failed while a fallback already runs: no second fallback
: >"$CALLS"; checked=""
f=$(spawn x -p "$QS_GOOD"); p=$(spawn x); log "$p" "ERROR: Failed to load configuration"
list_instances() { echo "$f"; echo "$p"; }
check_configs; sleep 0.2
check "failed with fallback up: not started twice" not_called "-p $QS_GOOD"
check "failed with fallback up: fallback kept" alive "$f"

# live config loads again: fallback retired, snapshot refreshed
: >"$CALLS"; checked=""
echo "shell v3" >"$TMP/src/shell.qml"
p=$(spawn x); log "$p" "INFO: Configuration Loaded"
list_instances() { echo "$f"; echo "$p"; }
check_configs; sleep 0.2
check "loaded with fallback up: fallback killed" dead "$f"
check "loaded: live instance kept" alive "$p"
check "loaded: snapshot refreshed" [ "$(cat "$QS_GOOD/shell.qml")" = "shell v3" ]
kill "$p"

# failed with no snapshot yet: told so, nothing started
: >"$CALLS"; checked=""; rm -rf "$QS_GOOD"
p=$(spawn x); log "$p" "ERROR: Failed to load configuration"
list_instances() { echo "$p"; }
check_configs
check "no snapshot: nothing started" not_called "-p $QS_GOOD"
check "no snapshot: user told about dots-rescue" called "dots-rescue"

finish
