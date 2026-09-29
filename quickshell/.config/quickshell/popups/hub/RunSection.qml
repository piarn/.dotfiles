// The hub's "run" section — what the launcher was. Plain text searches apps
// by name, description and keywords ("pdf" finds Zathura), most-launched
// first; a leading character switches mode:
//   =  calculator, Enter copies     >  shell command
//   /  files (empty: recently opened)
//   ?  web search                   @  open windows
// System actions, themes and layouts used to be a `:` mode here; they're
// hub sections now, reachable from the same search box.
// Items: {title, subtitle, icon (theme name) or glyph, key (usage
// counting), run(alt)}.
import Quickshell
import Quickshell.Io
import QtQuick
import "../../state"
import "search.js" as Search

Item {
    id: root

    readonly property string name: "run"
    readonly property string glyph: "\u{f0349}"

    property string query: ""
    property bool active: false   // the hub is open

    readonly property string home: Quickshell.env("HOME")
    readonly property string term: "kitty"
    readonly property string searchUrl: "https://duckduckgo.com/?q="

    readonly property var prefixes: ({ "=": "calc", ">": "run", "/": "files", "?": "web", "@": "windows" })
    readonly property string mode: prefixes[query.charAt(0)] ?? "apps"
    readonly property string rest: (mode === "apps" ? query : query.slice(1)).trim()

    property var windows: []
    property var recentFiles: []      // [{path, dir}]
    property var foundFiles: []       // fd results for foundFor
    property string foundFor: ""

    readonly property var apps: DesktopEntries.applications.values

    // Rows for a prefix mode (or the app list on an empty query).
    readonly property var results: {
        switch (mode) {
        case "calc": return calcResults()
        case "run": return runResults()
        case "files": return fileResults()
        case "web": return webResults()
        case "windows": return windowResults()
        default: return appResults(rest)
        }
    }

    readonly property string hint: {
        switch (mode) {
        case "calc":
            if (rest === "") return "2^10*3 · sqrt(2) · 15%4 · pi"
            return results.length ? "enter copies" : "not a valid expression"
        case "run": return "enter in " + term + " · shift+enter in background"
        case "files":
            if (rest === "") return (recentFiles.length ? "recent files" : "no recent files") + " · enter open · shift+enter show in Dolphin"
            if (fdProc.running && foundFor !== rest) return "searching…"
            return (results.length ? "" : "nothing matches · ") + "enter open · shift+enter show in Dolphin"
        case "web": return "enter search"
        case "windows": return "enter focus"
        default: return "=calc  >run  /files  ?web  @windows"
        }
    }

    function ranked(items, q, fieldsOf) {
        if (q === "") return items
        return items
            .map(it => ({ it, s: Search.match(fieldsOf(it), q) }))
            .filter(x => x.s >= 0)
            .sort((a, b) => b.s - a.s)
            .map(x => x.it)
    }

    // Apps matching q, each with its score `s` so the hub can merge them
    // with other sections' matches.
    function appResults(q) {
        const out = []
        for (const e of apps) {
            if (e.noDisplay) continue
            const key = "app:" + e.id
            const used = LauncherUsage.weight(key)
            let s = used
            if (q !== "") {
                const fields = [
                    { text: e.name, weight: 1, loose: true },
                    { text: e.genericName, weight: 0.8 },
                    { text: e.comment, weight: 0.5 },
                ].concat((e.keywords || []).map(k => ({ text: k, weight: 0.7 })))
                s = Search.match(fields, q)
                if (s < 0) continue
                s += 40 * Math.log2(1 + used)
            }
            out.push({ s, e, key })
        }
        out.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name))
        return out.map(({ s, e, key }) => ({
            key, s,
            kind: "action",
            title: e.name,
            subtitle: e.genericName || e.comment || "",
            icon: e.icon,
            // execute() ignores Terminal=true, so those go through kitty
            run: () => e.runInTerminal ? Quickshell.execDetached([root.term].concat(e.command)) : e.execute(),
        }))
    }

    function calcResults() {
        const expr = rest
        const v = expr === "" ? null : Search.calc(expr)
        if (v === null) return []
        const s = Search.formatNumber(v)
        return [{ kind: "action", title: s, subtitle: expr + " =", glyph: "\u{f00ec}",
                  run: () => Quickshell.execDetached(["wl-copy", "--", s]) }]
    }

    function runResults() {
        const cmd = rest
        if (cmd === "") return []
        return [{ kind: "action", title: cmd, subtitle: "run command", glyph: "\u{f018d}",
                  run: alt => Quickshell.execDetached(alt ? ["sh", "-c", cmd]
                                                          : [root.term, "--hold", "sh", "-c", cmd]) }]
    }

    function fileItem(f) {
        const path = f.path
        return {
            kind: "action",
            title: path.replace(/\/$/, "").split("/").pop(),
            subtitle: path.startsWith(home) ? "~" + path.slice(home.length) : path,
            glyph: f.dir ? "\u{f024b}" : "\u{f0214}",
            run: alt => Quickshell.execDetached(alt
                ? ["flatpak", "run", "org.kde.dolphin", "--select", path]
                : ["xdg-open", path]),
        }
    }

    function fileResults() {
        if (rest === "") return recentFiles.map(fileItem)
        return foundFiles.map(fileItem)
    }

    function webResults() {
        const q = rest
        if (q === "") return []
        const out = []
        // something that looks like an address opens directly
        if (/^\S+\.[a-z]{2,}(\/\S*)?$/i.test(q)) {
            const url = /^[a-z]+:\/\//i.test(q) ? q : "https://" + q
            out.push({ kind: "action", title: url, subtitle: "open address", glyph: "\u{f059f}",
                       run: () => Quickshell.execDetached(["xdg-open", url]) })
        }
        out.push({ kind: "action", title: q, subtitle: "search the web", glyph: "\u{f0349}",
                   run: () => Quickshell.execDetached(["xdg-open", root.searchUrl + encodeURIComponent(q)]) })
        return out
    }

    function windowResults() {
        const items = windows.map(w => {
            const entry = DesktopEntries.heuristicLookup(w.app)
            const where = w.ws === "__i3_scratch" ? "scratchpad" : "workspace " + w.ws
            return {
                kind: "action",
                title: w.title || w.app,
                subtitle: (entry ? entry.name : w.app) + " · " + where,
                appName: entry ? entry.name : w.app,
                icon: entry ? entry.icon : "",
                glyph: "\u{f05af}",
                run: () => Quickshell.execDetached(["swaymsg", "[con_id=" + w.id + "] focus"]),
            }
        })
        return ranked(items, rest, it => [
            { text: it.title, weight: 1, loose: true },
            { text: it.appName, weight: 1, loose: true },
        ])
    }

    onModeChanged: {
        if (!active) return
        if (mode === "windows") treeProc.running = true
        if (mode === "files") recentProc.running = true
    }

    onRestChanged: if (mode === "files" && rest !== "") fdDebounce.restart()

    Process {
        id: treeProc
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const walk = (n, ws) => {
                    if (n.type === "workspace") ws = n.name
                    const kids = (n.nodes || []).concat(n.floating_nodes || [])
                    if (!kids.length && n.pid && (n.type === "con" || n.type === "floating_con")) {
                        out.push({
                            id: n.id,
                            title: n.name || "",
                            app: n.app_id || (n.window_properties && n.window_properties.class) || "",
                            ws: ws || "",
                        })
                    }
                    for (const k of kids) walk(k, ws)
                }
                try { walk(JSON.parse(text), "") } catch (e) {}
                root.windows = out
            }
        }
    }

    // Recently opened files, merged from the host's list and each
    // flatpak's own (sandboxed apps keep theirs under ~/.var/app), newest
    // first, missing files dropped.
    Process {
        id: recentProc
        command: ["python3", "-c", `
import glob, os, re, urllib.parse
home = os.path.expanduser("~")
files = [home + "/.local/share/recently-used.xbel"] + glob.glob(home + "/.var/app/*/data/recently-used.xbel")
seen = {}
for f in files:
    try:
        s = open(f, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for href, mod in re.findall(r'<bookmark href="file://([^"]+)"[^>]*?modified="([^"]+)"', s):
        p = urllib.parse.unquote(href)
        if mod > seen.get(p, "") and os.path.exists(p):
            seen[p] = mod
for p in sorted(seen, key=seen.get, reverse=True)[:40]:
    print(p + ("/" if os.path.isdir(p) else ""))
`]
        stdout: StdioCollector {
            onStreamFinished: root.recentFiles = text.split("\n").filter(l => l)
                .map(p => ({ path: p, dir: p.endsWith("/") }))
        }
    }

    Timer {
        id: fdDebounce
        interval: 120
        onTriggered: root.findFiles()
    }

    // fd only takes one pattern, so it gets the longest word and the
    // results are narrowed and ranked against the whole query here.
    function findFiles() {
        if (fdProc.running || mode !== "files" || rest === "") return
        fdProc.query = rest
        fdProc.pattern = rest.split(/\s+/).reduce((a, b) => b.length > a.length ? b : a, "")
        fdProc.running = true
    }

    Process {
        id: fdProc
        property string query: ""
        property string pattern: ""
        command: ["fd", "--ignore-case", "--fixed-strings", "--absolute-path",
                  "--max-results", "400", "--", pattern, root.home]
        stdout: StdioCollector {
            onStreamFinished: {
                const q = fdProc.query
                root.foundFiles = text.split("\n").filter(l => l)
                    .map(p => {
                        const name = p.replace(/\/$/, "").split("/").pop()
                        const s = Search.match([{ text: name, weight: 1, loose: true },
                                                { text: p, weight: 0.5 }], q)
                        return { path: p, dir: p.endsWith("/"), s: s - p.length * 0.1 }
                    })
                    .filter(f => f.s > -1)
                    .sort((a, b) => b.s - a.s)
                    .slice(0, 50)
                root.foundFor = q
            }
        }
        // the query moved on while fd was running
        onExited: if (root.rest !== query) root.findFiles()
    }
}
