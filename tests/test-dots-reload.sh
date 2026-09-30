#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"

command -v sway >/dev/null || { echo "  skip  (no sway binary)"; exit 0; }
stub swaymsg 'case "$*" in *get_version*) exit 0 ;; esac; echo "swaymsg $*" >>"$CALLS"'
stub pkill 'echo "pkill $*" >>"$CALLS"'

cp "$HOME/.config/sway/config" "$TMP/good.conf"
{ cat "$HOME/.config/sway/config"; echo "floating_modifier nope nope"; } >"$TMP/bad.conf"

: >"$CALLS"; DOTS_SWAY_CONFIG=$TMP/good.conf "$BIN/dots-reload" sway >/dev/null 2>&1
check "valid config: sway reloaded" called "reload"

: >"$CALLS"; out=$(DOTS_SWAY_CONFIG=$TMP/bad.conf "$BIN/dots-reload" sway 2>&1)
check "broken config: no reload" not_called "reload"
check "broken config: says why" grep -q "not reloading sway" <<<"$out"

: >"$CALLS"; DOTS_SWAY_CONFIG=$TMP/bad.conf "$BIN/dots-reload" quickshell >/dev/null 2>&1
check "broken config: quickshell not killed (no reload to respawn it)" not_called "pkill"

finish
