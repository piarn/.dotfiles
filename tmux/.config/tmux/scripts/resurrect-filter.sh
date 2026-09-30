#!/bin/sh
# resurrect post-save-layout hook: drop sessions not marked with @persist.
f="$1"
keep=$(tmux list-sessions -F '#{session_name}	#{@persist}' | awk -F'\t' '$2=="1"{print $1}')
awk -F'\t' -v keep="$keep" '
BEGIN { n = split(keep, a, "\n"); for (i = 1; i <= n; i++) k[a[i]] = 1 }
$1 == "pane" || $1 == "window" { if ($2 in k) print; next }
$1 == "state" { print; next }
$1 == "grouped_session" { if ($2 in k) print; next }
{ print }
' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
