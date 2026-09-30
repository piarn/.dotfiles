#!/usr/bin/env bash
# The island's name -> tab routing (island/routes.js) under node.
. "$(dirname "$0")/lib.sh"

command -v node >/dev/null || { echo "  skip  (no node)"; exit 0; }
js=$REPO/quickshell/.config/quickshell/island/routes.js
js() { node -e "$(grep -v '^\.pragma' "$js" 2>/dev/null); console.log(JSON.stringify($1))"; }
is() { [ "$(js "$1")" = "$2" ]; }

check "tab order" is "TABS" '["system","calendar","notifications","network","themes","run","clipboard"]'
check "tab names route to themselves" is "TABS.map(tabFor)" '["system","calendar","notifications","network","themes","run","clipboard"]'
check "theme -> themes" is "tabFor('theme')" '"themes"'
check "quicksettings -> system" is "tabFor('quicksettings')" '"system"'
check "battery -> system" is "tabFor('battery')" '"system"'
check "bluetooth -> network" is "tabFor('bluetooth')" '"network"'
check "commandcenter -> run" is "tabFor('commandcenter')" '"run"'
check "unknown -> empty" is "tabFor('nope')" '""'
check "next wraps" is "step('clipboard', 1)" '"system"'
check "prev wraps" is "step('system', -1)" '"clipboard"'
check "step from nothing starts at system" is "step('', 1)" '"system"'
check "run and clipboard want the keyboard" is "TABS.filter(wantsKeyboard)" '["run","clipboard"]'

finish
