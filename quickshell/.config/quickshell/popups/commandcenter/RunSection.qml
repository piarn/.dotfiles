// The command center's mode dispatcher. Plain text searches apps by name,
// description and keywords ("pdf" finds Zathura), most-launched first; a
// leading character forces a mode:
//   =  calculator, Enter copies     >  shell command
//   /  files (empty: recently opened)
//   ?  web search                   @  open windows
//   ~  dev: tmux sessions, git projects, ssh hosts (needs devRows)
//   !  tools: capture, clipboard, notifications (needs toolRows)
//   :  system actions (lock/reload/suspend/logout/reboot/shutdown),
//      :theme <name>, :layout <name>
// A prefix forces its scope, but it's never required to reach something:
// once the plain apps search has a query, it also folds in dev/tools/
// session/window matches (extraMatches, merged by score in
// defaultResults) so typing a project, action, or open window's name
// finds it without the prefix — the prefix is an accelerator/
// disambiguator, not a requirement. Each of those rows carries a `group`
// (session/project/ssh/capture/clipboard/notifications/window), shown as
// a tag so it's clear why a non-app result showed up. Files are the one
// mode that doesn't fold in — that needs running fd, too expensive to
// fire on every keystroke on the chance it's wanted. Nothing at all
// matches -> defaultResults falls back to the same "search the web" row
// `?` gives, instead of a dead end.
// devRows/toolRows are handed in from outside (CommandCenter.qml's
// DevSection/ToolsSection instances) rather than owned here, keeping this
// section a pure data/ranking layer.
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
    readonly property string glyph: "\u{e5c3}"   // apps

    property string query: ""
    property bool active: false   // the command center is open
    property var devRows: []
    property var toolRows: []
    signal openPopup(string popup)

    readonly property string home: Quickshell.env("HOME")
    readonly property string term: "kitty"
    readonly property string searchUrl: "https://duckduckgo.com/?q="

    readonly property var prefixes: ({ "=": "calc", ">": "run", "/": "files", "?": "web", "@": "windows",
                                        "~": "dev", "!": "tools", ":": "session" })
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
        case "dev": return devResults()
        case "tools": return toolResults()
        case "session": return sessionResults()
        default: return defaultResults(rest)
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
        case "dev": return "enter opens a tmux session"
        case "tools": return "enter runs · toggles stay open"
        case "session": return rest.match(/^(theme|layout)\b/) ? "enter applies" : "enter acts · destructive actions need enter twice"
        default: return "=calc  >run  /files  ?web  @windows  ~dev  !tools  :session"
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

    // Same as ranked(), but most-used-first on an empty query and boosted
    // by usage on a non-empty one — same frecency treatment as apps. Only
    // for items with a `key` (dev rows); tools deliberately don't get this,
    // they stay in their authored order.
    function rankedByUsage(items, q, fieldsOf) {
        if (q === "")
            return items.slice().sort((a, b) => LauncherUsage.weight(b.key || "") - LauncherUsage.weight(a.key || ""))
        return items
            .map(it => ({ it, s: Search.match(fieldsOf(it), q) }))
            .filter(x => x.s >= 0)
            .map(x => ({ it: x.it, s: x.s + 40 * Math.log2(1 + LauncherUsage.weight(x.it.key || "")) }))
            .sort((a, b) => b.s - a.s)
            .map(x => x.it)
    }

    // Apps matching q, most-used first once a query narrows them.
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

    // dev/tools/session/window rows, scored against q the same way apps
    // are, for defaultResults() to fold into the plain apps search. Empty
    // on an empty query — this only ever narrows an active search, it
    // doesn't replace the app list. Files aren't included: finding them
    // means running fd, too expensive to fire on every default-mode
    // keystroke just in case — `/` stays required for those.
    function extraMatches(q) {
        if (q === "") return []
        const out = []
        const fields = it => [
            { text: it.title, weight: 1, loose: true },
            { text: it.aliases || it.subtitle || "", weight: 0.6 },
            { text: it.appName || "", weight: 0.8, loose: true },
        ]
        const add = (rows) => {
            for (const it of rows) {
                if (it.kind === "header") continue
                const s = Search.match(fields(it), q)
                if (s < 0) continue
                out.push({ s: s + 40 * Math.log2(1 + LauncherUsage.weight(it.key || "")), it })
            }
        }
        add(devRows)
        add(toolActionRows())
        add(sessionActionRows())
        add(windowActionRows())
        return out
    }

    // Plain apps search, folding in dev/tools/session/window matches once
    // a query narrows it (see extraMatches above). Nothing at all matches
    // -> offer the same "search the web" escape hatch `?` gives, rather
    // than a dead end.
    function defaultResults(q) {
        const appRows = appResults(q)
        if (q === "") return appRows
        const merged = appRows.map(it => ({ s: it.s, it }))
            .concat(extraMatches(q))
            .sort((a, b) => b.s - a.s)
            .map(x => x.it)
        return merged.length ? merged : webResults(q)
    }

    function calcResults() {
        const expr = rest
        const v = expr === "" ? null : Search.calc(expr)
        if (v === null) return []
        const s = Search.formatNumber(v)
        return [{ kind: "action", title: s, subtitle: expr + " =", glyph: "\u{ea5f}",   // calculate
                  run: () => Quickshell.execDetached(["wl-copy", "--", s]) }]
    }

    function runResults() {
        const cmd = rest
        if (cmd === "") return []
        return [{ kind: "action", title: cmd, subtitle: "run command", glyph: "\u{eb8e}",   // terminal
                  run: alt => Quickshell.execDetached(alt ? ["sh", "-c", cmd]
                                                          : [root.term, "--hold", "sh", "-c", cmd]) }]
    }

    function fileItem(f) {
        const path = f.path
        return {
            kind: "action",
            title: path.replace(/\/$/, "").split("/").pop(),
            subtitle: path.startsWith(home) ? "~" + path.slice(home.length) : path,
            glyph: f.dir ? "\u{e2c8}" : "\u{e873}",   // folder_open / description
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
            out.push({ kind: "action", title: url, subtitle: "open address", glyph: "\u{e89d}",   // open_in_browser
                       run: () => Quickshell.execDetached(["xdg-open", url]) })
        }
        out.push({ kind: "action", title: q, subtitle: "search the web", glyph: "\u{ef7a}",   // search
                   run: () => Quickshell.execDetached(["xdg-open", root.searchUrl + encodeURIComponent(q)]) })
        return out
    }

    function windowActionRows() {
        return windows.map(w => {
            const entry = DesktopEntries.heuristicLookup(w.app)
            const where = w.ws === "__i3_scratch" ? "scratchpad" : "workspace " + w.ws
            return {
                kind: "action", group: "window",
                title: w.title || w.app,
                subtitle: (entry ? entry.name : w.app) + " · " + where,
                appName: entry ? entry.name : w.app,
                icon: entry ? entry.icon : "",
                glyph: "\u{f088}",   // window
                run: () => Quickshell.execDetached(["swaymsg", "[con_id=" + w.id + "] focus"]),
            }
        })
    }

    function windowResults() {
        return ranked(windowActionRows(), rest, it => [
            { text: it.title, weight: 1, loose: true },
            { text: it.appName, weight: 1, loose: true },
        ])
    }

    function devResults() {
        return rankedByUsage(devRows.filter(r => r.kind !== "header"), rest, it => [
            { text: it.title, weight: 1, loose: true },
            { text: it.aliases || "", weight: 0.6 },
        ])
    }

    // toolRows as-is except "page" (clipboard history) becomes a plain
    // action that opens that popup directly — there's no stack navigation
    // here to push a page onto, unlike the old hub.
    function toolActionRows() {
        return toolRows.filter(r => r.kind !== "header").map(it => it.kind === "page" ? Object.assign({}, it, {
            kind: "action", run: () => root.openPopup(it.group === "clipboard" ? "clipboard" : "notifications"),
        }) : it)
    }

    // Deliberately plain ranked(), not rankedByUsage(): tools stay in
    // their authored order rather than reshuffling by how often you use
    // each one.
    function toolResults() {
        return ranked(toolActionRows(), rest, it => [
            { text: it.title, weight: 1, loose: true },
            { text: it.aliases || "", weight: 0.6 },
        ])
    }

    readonly property var sessionActions: [
        { title: "lock", glyph: "\u{e899}", aliases: "screen",
          cmd: ["qs", "ipc", "call", "lock", "lock"] },
        { title: "reload", glyph: "\u{e5d5}", aliases: "restart refresh sway quickshell tmux kitty config",
          cmd: [Quickshell.env("HOME") + "/.local/bin/dots-reload"] },
        { title: "suspend", glyph: "\u{f159}", aliases: "sleep",
          cmd: ["systemctl", "suspend"] },
        { title: "logout", glyph: "\u{e9ba}", aliases: "exit quit sway",
          cmd: ["swaymsg", "exit"], confirm: true },
        { title: "reboot", glyph: "\u{f053}", aliases: "restart",
          cmd: ["systemctl", "reboot"], confirm: true },
        { title: "shutdown", glyph: "\u{f8c7}", aliases: "poweroff off halt",
          cmd: ["systemctl", "poweroff"], confirm: true },
    ]

    // sessionActions as plain rows — lock/reload/suspend/logout/reboot/
    // shutdown only, not the :theme/:layout sub-modes (those need a name
    // typed after them, so they don't make sense as bare defaultResults()
    // matches the way a one-shot action does).
    function sessionActionRows() {
        return sessionActions.map(a => ({
            kind: "action", group: "session", title: a.title, subtitle: a.aliases, glyph: a.glyph, confirm: !!a.confirm,
            run: () => Quickshell.execDetached(a.cmd),
        }))
    }

    function sessionResults() {
        const m = rest.match(/^(theme|layout)\s*(.*)$/i)
        if (m) {
            const q = m[2].trim()
            if (m[1].toLowerCase() === "theme")
                return ranked(RiceState.themes, q, t => [{ text: t.name, weight: 1, loose: true }])
                    .map(t => ({ kind: "theme", group: "theme", title: t.name, colors: t.colors, wallpaper: t.wallpaper,
                                 subtitle: t.id === RiceState.currentTheme ? "current theme" : "",
                                 on: t.id === RiceState.currentTheme, run: () => RiceState.applyTheme(t.id) }))
            return ranked(RiceState.layouts, q, l => [{ text: l, weight: 1, loose: true }])
                .map(l => ({ kind: "choice", group: "layout", title: l, subtitle: l === RiceState.currentLayout ? "current layout" : "apply screen layout",
                             glyph: "\u{e9b0}", on: l === RiceState.currentLayout, run: () => RiceState.applyLayout(l) }))
        }
        return ranked(sessionActionRows(), rest, a => [
            { text: a.title, weight: 1, loose: true },
            { text: a.subtitle, weight: 0.6 },
        ])
    }

    // Windows load as soon as the command center opens, not just on
    // switching into `@` mode: the plain apps search folds window matches
    // in too (extraMatches), so it needs them ready before you've typed
    // anything mode-specific.
    onActiveChanged: if (active) treeProc.running = true

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
