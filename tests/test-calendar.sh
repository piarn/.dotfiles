#!/usr/bin/env bash
# The calendar tab's date math (island/calendar.js) under node.
. "$(dirname "$0")/lib.sh"

command -v node >/dev/null || { echo "  skip  (no node)"; exit 0; }
js=$REPO/quickshell/.config/quickshell/island/calendar.js

# js EXPR: prints EXPR evaluated with calendar.js loaded (its QML-only
# `.pragma library` line dropped)
js() { node -e "$(grep -v '^\.pragma' "$js" 2>/dev/null); console.log(JSON.stringify($1))"; }
is() { [ "$(js "$1")" = "$2" ]; }

check "iso week: mid-year" is "isoWeek(new Date(2026, 8, 30))" '{"week":40,"year":2026}'
check "iso week: 1 Jan 2027 is week 53 of 2026" is "isoWeek(new Date(2027, 0, 1))" '{"week":53,"year":2026}'
check "iso week: 29 Dec 2025 is week 1 of 2026" is "isoWeek(new Date(2025, 11, 29))" '{"week":1,"year":2026}'
check "iso week: Sunday belongs to its Monday's week" is "isoWeek(new Date(2026, 9, 4)).week" '40'
check "day of year: 30 Sep 2026" is "dayOfYear(new Date(2026, 8, 30))" '273'
check "day of year: 31 Dec in a leap year" is "dayOfYear(new Date(2028, 11, 31))" '366'

check "grid: always 6 weeks of 7 days" is "monthGrid(2026, 1).map(w => w.days.length)" '[7,7,7,7,7,7]'
check "grid: Sep 2026 starts on Monday 31 Aug" is "monthGrid(2026, 8)[0].days[0]" '{"day":31,"month":7,"year":2026,"inMonth":false}'
check "grid: 1 Sep is its Tuesday" is "monthGrid(2026, 8)[0].days[1]" '{"day":1,"month":8,"year":2026,"inMonth":true}'
check "grid: week numbers down the side" is "monthGrid(2026, 8).map(w => w.week)" '[36,37,38,39,40,41]'
check "grid: a month starting on Monday starts in row 1" is "monthGrid(2026, 5)[0].days[0].day" '1'
check "grid: January crosses the year edge" is "monthGrid(2027, 0)[0].week" '53'
check "grid: December rolls into January" is "monthGrid(2026, 11)[5].days[6]" '{"day":10,"month":0,"year":2027,"inMonth":false}'

check "monthName" is "monthName(8)" '"september"'

finish
