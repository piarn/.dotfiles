#!/usr/bin/env bash
# The lock screen's QML can't run here, so this pins the one line dots-lock
# trusts: isLocked must report the compositor-confirmed state (secure),
# not merely the requested one (locked), or a lock sway refused would
# stop dots-lock from falling back to swaylock.
. "$(dirname "$0")/lib.sh"
qml=$REPO/quickshell/.config/quickshell/popups/LockScreen.qml
check "isLocked reports the confirmed lock (secure)" grep -q 'function isLocked(): bool { return sessionLock.secure }' "$qml"
finish
