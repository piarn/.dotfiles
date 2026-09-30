#!/usr/bin/env bash
# Sourced by tests/test-*.sh. Stubs go first on PATH so a test never
# reaches the live session's quickshell, sway or lockers.
set -u
fails=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BIN=$REPO/scripts/.local/bin
CALLS=$TMP/calls
: >"$CALLS"
mkdir -p "$TMP/stubs"
export PATH="$TMP/stubs:$PATH"

# stub NAME BODY: a command NAME on PATH running BODY (sh), which can
# append to $CALLS to record that it ran.
stub() {
    printf '#!/bin/sh\nCALLS=%s\n%s\n' "$CALLS" "$2" >"$TMP/stubs/$1"
    chmod +x "$TMP/stubs/$1"
}

check() {
    local name=$1
    shift
    if "$@"; then printf '  ok    %s\n' "$name"; else printf '  FAIL  %s\n' "$name"; fails=$((fails + 1)); fi
}

called() { grep -qF -- "$1" "$CALLS"; }
not_called() { ! grep -qF -- "$1" "$CALLS"; }

finish() { [ "$fails" -eq 0 ]; }
