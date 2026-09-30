#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"

# qs stub: QS_MODE works | slow | broken | none
stub qs '
echo "qs $*" >>"$CALLS"
case "$QS_MODE:$4" in
    works:lock) touch "$CALLS.locked" ;;
    slow:lock) (sleep 0.5; touch "$CALLS.locked") & ;;
    works:isLocked|slow:isLocked) [ -e "$CALLS.locked" ] && echo true || echo false ;;
    broken:*) echo "Target not found." ;;
    none:*) exit 255 ;;
esac'
stub swaylock 'echo "swaylock $*" >>"$CALLS"'
stub logger ':'
stub pgrep 'exit "${PGREP_RC:-1}"'

export DOTS_LOCK_QS=$TMP/stubs/qs DOTS_LOCK_FLAG=$TMP/flag DOTS_LOCK_WAIT=3

reset() { : >"$CALLS"; rm -f "$CALLS.locked"; echo 1 >"$TMP/flag"; }

reset; QS_MODE=works "$BIN/dots-lock"
check "quickshell locks: asks it to lock" called "qs ipc call lock lock"
check "quickshell locks: no swaylock" not_called "swaylock"

reset; QS_MODE=broken "$BIN/dots-lock"
check "config didn't load (target missing): swaylock" called "swaylock -f -c"

reset; QS_MODE=none "$BIN/dots-lock"
check "quickshell not running: swaylock" called "swaylock -f -c"

reset; QS_MODE=broken "$BIN/dots-lock"; sleep 0.3
check "swaylock fallback: stale lock flag reset once swaylock is gone" [ "$(cat "$TMP/flag")" = 0 ]

reset; PGREP_RC=0 QS_MODE=broken "$BIN/dots-lock"
check "swaylock already running: nothing started" not_called "swaylock"
check "swaylock already running: quickshell not asked" not_called "call lock lock"

reset; touch "$CALLS.locked"; QS_MODE=works "$BIN/dots-lock"
check "already locked by quickshell: not asked again" not_called "call lock lock"

reset; QS_MODE=slow DOTS_LOCK_WAIT=20 "$BIN/dots-lock"
check "slow quickshell within the wait: no swaylock" not_called "swaylock"

reset; QS_MODE=slow DOTS_LOCK_WAIT=1 "$BIN/dots-lock"
check "slow quickshell past the wait: swaylock" called "swaylock -f -c"

finish
