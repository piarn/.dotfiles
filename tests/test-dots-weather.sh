#!/usr/bin/env bash
# dots-weather against file:// fixtures standing in for Open-Meteo.
. "$(dirname "$0")/lib.sh"

W=$BIN/dots-weather
export DOTS_WEATHER_CONF=$TMP/weather.conf DOTS_WEATHER_CACHE=$TMP/cache/weather.json
export DOTS_WEATHER_GEO_URL="file://$TMP/geo.json" DOTS_WEATHER_FORECAST_URL="file://$TMP/forecast.json"
echo '{"results":[{"name":"Vilnius","latitude":54.69,"longitude":25.28,"country":"Lithuania"}]}' >"$TMP/geo.json"
forecast() { printf '{"current":{"temperature_2m":%s,"weather_code":%s,"is_day":%s},"daily":{"sunrise":["2026-09-30T07:12"],"sunset":["2026-09-30T19:03"]}}\n' "$1" "$2" "$3" >"$TMP/forecast.json"; }
field() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$DOTS_WEATHER_CACHE" "$1"; }
is() { [ "$(field "$1")" = "$2" ]; }

forecast 15.2 3 1
"$W" >/dev/null 2>&1; rc=$?
check "no city configured: not an error" [ "$rc" = 0 ]
check "no city configured: nothing written" [ ! -e "$DOTS_WEATHER_CACHE" ]

echo "city=Vilnius" >"$DOTS_WEATHER_CONF"
"$W"
check "overcast: temperature rounded" is temp 15
check "overcast: description" is desc overcast
check "overcast: cloud glyph" is glyph $''
check "city recorded" is city Vilnius
check "update time recorded" [ "$(field updated)" -gt 1700000000 ]
check "sunrise recorded" is sunrise "2026-09-30T07:12"
check "sunset recorded" is sunset "2026-09-30T19:03"

forecast 3.4 0 0; "$W"
check "clear at night: moon glyph" is glyph $''
check "clear at night: description" is desc clear
forecast 21 0 1; "$W"
check "clear by day: sun glyph" is glyph $''
forecast -0.4 71 1; "$W"
check "no negative zero" is temp 0
check "light snow: description" is desc "light snow"
check "light snow: snow glyph" is glyph $''
forecast 12 95 1; "$W"
check "thunderstorm glyph" is glyph $''
forecast 12 42 1; "$W"
check "unknown code: still written" is desc "unknown"

# coordinates are cached: a dead geocoder doesn't matter any more
forecast 9 63 1
DOTS_WEATHER_GEO_URL="file://$TMP/nope.json" "$W"
check "cached location: works without the geocoder" is desc rain

cp "$DOTS_WEATHER_CACHE" "$TMP/before.json"
DOTS_WEATHER_FORECAST_URL="file://$TMP/nope.json" "$W" 2>/dev/null; rc=$?
check "forecast down: fails" [ "$rc" != 0 ]
check "forecast down: last weather kept" cmp -s "$TMP/before.json" "$DOTS_WEATHER_CACHE"

echo "city=Nowhere" >"$DOTS_WEATHER_CONF"
echo '{"results":[]}' >"$TMP/geo.json"
out=$("$W" 2>&1); rc=$?
check "unknown city: fails" [ "$rc" != 0 ]
check "unknown city: says so" grep -q "not found" <<<"$out"

finish
