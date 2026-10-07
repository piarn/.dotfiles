#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"

# sway stub: SWAY_STUB fast-fail | slow-fail | ok | safe-ok (fails unless given -c)
# SWAY_STUB_VERSION: what `sway --version` reports (default 1.12)
stub sway '
case "$1" in --version) echo "sway version ${SWAY_STUB_VERSION:-1.12}"; exit 0 ;; esac
echo "sway $*" >>"$CALLS"
echo "explicit-sync-off=${WLR_RENDER_NO_EXPLICIT_SYNC:-unset}" >>"$CALLS"
case "$SWAY_STUB" in
    fast-fail) exit 1 ;;
    slow-fail) sleep 3; exit 1 ;;
    ok) exit 0 ;;
    safe-ok) case "$*" in *"-c "*) exit 0 ;; *) exit 1 ;; esac ;;
esac'
# 2s threshold vs instant/3s stubs: date +%s has 1s resolution, so an
# instant failure can still read as 1s
export XDG_STATE_HOME=$TMP/state SWAY_SESSION_FAST_FAIL=2 SWAY_SESSION_SAFE_CONFIG=/safe/config
S=$REPO/.bootstrap/sway-session

: >"$CALLS"; SWAY_STUB=ok "$S"; rc=$?
check "clean exit: sway run once" [ "$(grep -c '^sway' "$CALLS")" = 1 ]
check "clean exit: status 0" [ "$rc" = 0 ]
# Explicit sync is what keeps NVIDIA frames from flickering, so it stays on
# from sway 1.12 (wlroots 0.20) on ...
check "sway 1.12: explicit sync left on" called "explicit-sync-off=unset"
# ... but wlroots 0.19's explicit-sync release path aborts sway
# (buffer->n_locks > 0 assertion) when e.g. a new kitty starts
for v in 1.11 1.11-dev; do
    : >"$CALLS"; SWAY_STUB=ok SWAY_STUB_VERSION=$v "$S"
    check "sway $v: explicit sync disabled" called "explicit-sync-off=1"
done

: >"$CALLS"; SWAY_STUB=safe-ok "$S"; rc=$?
check "fast failure: retried with the safe config" called "-c /safe/config"
check "fast failure: safe mode's status returned" [ "$rc" = 0 ]
check "fast failure: logged" grep -q "safe mode" "$XDG_STATE_HOME/sway.log"

: >"$CALLS"; SWAY_STUB=fast-fail "$S"; rc=$?
check "safe mode fails too: back to GDM (non-zero)" [ "$rc" != 0 ]
check "safe mode fails too: only one retry" [ "$(grep -c '^sway' "$CALLS")" = 2 ]

: >"$CALLS"; SWAY_STUB=slow-fail "$S"; rc=$?
check "failure after a long session: no retry" [ "$(grep -c '^sway' "$CALLS")" = 1 ]
check "failure after a long session: status kept" [ "$rc" != 0 ]

finish
