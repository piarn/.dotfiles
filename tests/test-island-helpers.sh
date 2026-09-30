#!/usr/bin/env bash
# island/tabs/clip.js (clipboard entry kinds) and island/format.js (ago,
# year progress) under node.
. "$(dirname "$0")/lib.sh"

command -v node >/dev/null || { echo "  skip  (no node)"; exit 0; }
Q=$REPO/quickshell/.config/quickshell/island
js() { node -e "$(grep -hv '^\.pragma' "$Q/tabs/clip.js" "$Q/format.js" 2>/dev/null); console.log(JSON.stringify($1))"; }
is() { [ "$(js "$1")" = "$2" ]; }

check "link" is "classify('https://example.com/a?b=1').kind" '"link"'
check "file url is a file" is "classify('file:///home/a/x.mp4').kind" '"file"'
check "absolute path is a file" is "classify('/etc/sway/config').kind" '"file"'
check "home path is a file" is "classify('~/notes.md').kind" '"file"'
check "hex colour" is "classify('#edeceb')" '{"kind":"color","color":"#edeceb","subtitle":"colour"}'
check "short hex colour" is "classify('#fff').kind" '"color"'
check "not a colour" is "classify('#hashtag').kind" '"text"'
check "image, with its size" is "classify('[[ binary data 9 KiB png 481x57 ]]')" '{"kind":"image","title":"image","subtitle":"image · png · 481×57 · 9 KiB"}'
check "other binary" is "classify('[[ binary data 2 MiB application/pdf ]]').kind" '"binary"'
check "code-ish text" is "classify('const x = () => { return 1; }').kind" '"code"'
check "plain text subtitle counts chars" is "classify('Customer').subtitle" '"text · 8 chars"'
check "cliphist's cut-off previews read 100+" is "classify('x'.repeat(101)).subtitle" '"text · 100+ chars"'
check "image title" is "classify('[[ binary data 9 KiB png 481x57 ]]').title" '"image"'
check "glyph per kind" is "['link','file','color','image','binary','code','text'].map(k => GLYPHS[k].length)" '[1,1,1,1,1,1,1]'

check "dedupe keeps the newest of each" is "dedupe([{id:'3',preview:'a'},{id:'2',preview:'b'},{id:'1',preview:'a'}]).map(e => e.id)" '["3","2"]'

check "ago: just now" is "ago(1000, 30 * 1000)" '"now"'
check "ago: minutes" is "ago(0, 5 * 60 * 1000)" '"5m"'
check "ago: hours" is "ago(0, 3 * 3600 * 1000 + 59000)" '"3h"'
check "ago: days" is "ago(0, 2 * 86400 * 1000)" '"2d"'
check "year progress" is "yearProgress(new Date(2026, 6, 2, 12))" '50'
check "year progress, first day" is "yearProgress(new Date(2026, 0, 1))" '0'
check "daylight" is "daylight('2026-09-30T07:12', '2026-09-30T19:03')" '"11h 51m"'
check "groupBy keeps first-seen order" is "groupBy([{a:'x',n:1},{a:'y',n:2},{a:'x',n:3}], i => i.a).map(g => [g.key, g.items.map(i => i.n)])" '[["x",[1,3]],["y",[2]]]'
check "groupBy empty" is "groupBy([], i => i)" '[]'
check "clock time from iso" is "hhmm('2026-09-30T07:12')" '"07:12"'

finish
