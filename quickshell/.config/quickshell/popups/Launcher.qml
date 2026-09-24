// App launcher, replacing wofi. Hidden by default; toggled from sway via
// `bindsym $mod+space exec qs ipc call launcher toggle` (see
// ~/.dots/sway/.config/sway/config) instead of a global shortcut, since
// wlroots compositors like sway don't expose one to arbitrary clients.
//
// Plain text searches apps by name, description and keywords ("pdf" finds
// Zathura), with the ones you launch most on top. A leading character
// switches mode:
//   =  calculator, Enter copies     :  system actions, :theme, :layout
//   >  shell command                /  files (empty: recently opened)
//   ?  web search                   @  open windows
// Matching and the calculator live in launcher/search.js, launch counts
// in state/LauncherUsage.qml.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import quickshell
import "../components"
import "../state"
import "launcher/search.js" as Search

CardWindow {
    id: launcher
    visible: false
    centered: true
    needsKeyboard: true
    clickAwayCloses: true
    cardWidth: 560
    cardHeight: body.implicitHeight + 24
    initialFocus: input
    WlrLayershell.namespace: "quickshell-launcher"
    onDismissed: launcher.visible = false

    readonly property string home: Quickshell.env("HOME")
    readonly property string rice: home + "/.rice"
    readonly property string term: "kitty"
    readonly property string searchUrl: "https://duckduckgo.com/?q="
    readonly property int rowHeight: 40
    readonly property int maxRows: 8

    property string query: ""
    property int selected: 0

    readonly property var prefixes: ({ "=": "calc", ":": "system", ">": "run", "/": "files", "?": "web", "@": "windows" })
    readonly property string mode: prefixes[query.charAt(0)] ?? "apps"
    readonly property string rest: (mode === "apps" ? query : query.slice(1)).trim()

    // Filled in by the processes below: rice themes/layouts on open, the
    // rest when their mode is entered.
    property var themes: []
    property var layouts: []
    property string currentTheme: ""
    property string currentLayout: ""
    property var windows: []
    property var recentFiles: []      // [{path, dir}]
    property var foundFiles: []       // fd results for foundFor
    property string foundFor: ""

    readonly property var apps: DesktopEntries.applications.values

    readonly property var actions: [
        { title: "lock", subtitle: "lock the screen", glyph: "\u{f023}",
          run: () => Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"]) },
        { title: "theme", subtitle: "switch the rice theme", glyph: "\u{f03d8}", complete: ":theme " },
        { title: "layout", subtitle: "switch the screen layout", glyph: "\u{f0379}", complete: ":layout ", aliases: "monitor screen display" },
        { title: "reload", subtitle: "reload sway and restart quickshell", glyph: "\u{f0450}", aliases: "restart refresh sway",
          run: () => Quickshell.execDetached(["sh", "-c", "pkill -KILL -x quickshell; swaymsg reload"]) },
        { title: "suspend", subtitle: "sleep", glyph: "\u{f04b2}", aliases: "sleep",
          run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { title: "logout", subtitle: "exit sway", glyph: "\u{f0343}", aliases: "exit quit",
          run: () => Quickshell.execDetached(["swaymsg", "exit"]) },
        { title: "reboot", subtitle: "restart the computer", glyph: "\u{f0709}", aliases: "restart",
          run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { title: "shutdown", subtitle: "power off", glyph: "\u{f011}", aliases: "poweroff off halt",
          run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
    ]

    readonly property var results: {
        switch (mode) {
        case "calc": return calcResults()
        case "system": return systemResults()
        case "run": return runResults()
        case "files": return fileResults()
        case "web": return webResults()
        case "windows": return windowResults()
        default: return appResults()
        }
    }
    onResultsChanged: selected = Math.min(selected, Math.max(results.length - 1, 0))
    onQueryChanged: selected = 0

    readonly property string footer: {
        const nav = "↑↓ move · esc close"
        switch (mode) {
        case "calc":
            if (rest === "") return "2^10*3 · sqrt(2) · 15%4 · pi · " + nav
            return results.length ? "enter copies · " + nav : "not a valid expression"
        case "system": return "enter run · tab complete · " + nav
        case "run": return "enter in " + term + " · shift+enter in background · " + nav
        case "files":
            if (rest === "") return (recentFiles.length ? "recent files" : "no recent files") + " · enter open · shift+enter show in Dolphin"
            if (fdProc.running && foundFor !== rest) return "searching…"
            return (results.length ? "" : "nothing matches · ") + "enter open · shift+enter show in Dolphin"
        case "web": return "enter search · " + nav
        case "windows": return "enter focus · " + nav
        default: return "=calc  :system  >run  /files  ?web  @windows"
        }
    }

    // Items: {title, subtitle, icon (theme name) or glyph, key (usage
    // counting), run(alt), or complete (text to put in the box instead)}.

    function ranked(items, q, fieldsOf) {
        if (q === "") return items
        return items
            .map(it => ({ it, s: Search.match(fieldsOf(it), q) }))
            .filter(x => x.s >= 0)
            .sort((a, b) => b.s - a.s)
            .map(x => x.it)
    }

    function appResults() {
        const q = rest
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
        return out.map(({ e, key }) => ({
            key,
            title: e.name,
            subtitle: e.genericName || e.comment || "",
            icon: e.icon,
            // execute() ignores Terminal=true, so those go through kitty
            run: () => e.runInTerminal ? Quickshell.execDetached([launcher.term].concat(e.command)) : e.execute(),
        }))
    }

    function calcResults() {
        const expr = rest
        const v = expr === "" ? null : Search.calc(expr)
        if (v === null) return []
        const s = Search.formatNumber(v)
        return [{ title: s, subtitle: expr + " =", glyph: "\u{f00ec}",
                  run: () => Quickshell.execDetached(["wl-copy", "--", s]) }]
    }

    function systemResults() {
        const sub = rest.match(/^(theme|layout)\b\s*(.*)$/i)
        if (!sub) return ranked(actions, rest, a => [
            { text: a.title, weight: 1, loose: true },
            { text: a.aliases || "", weight: 0.8 },
            { text: a.subtitle, weight: 0.5 },
        ])
        const which = sub[1].toLowerCase()
        const names = which === "theme" ? themes : layouts
        const current = which === "theme" ? currentTheme : currentLayout
        const items = names.map(n => ({
            title: n,
            subtitle: n === current ? "current " + which : "",
            glyph: which === "theme" ? "\u{f03d8}" : "\u{f0379}",
            run: () => Quickshell.execDetached([launcher.rice + "/bin/apply-" + which, n]),
        }))
        return ranked(items, sub[2].trim(), it => [{ text: it.title, weight: 1, loose: true }])
    }

    function runResults() {
        const cmd = rest
        if (cmd === "") return []
        return [{ title: cmd, subtitle: "run command", glyph: "\u{f018d}",
                  run: alt => Quickshell.execDetached(alt ? ["sh", "-c", cmd]
                                                          : [launcher.term, "--hold", "sh", "-c", cmd]) }]
    }

    function fileItem(f) {
        const path = f.path
        return {
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
            out.push({ title: url, subtitle: "open address", glyph: "\u{f059f}",
                       run: () => Quickshell.execDetached(["xdg-open", url]) })
        }
        out.push({ title: q, subtitle: "search the web", glyph: "\u{f0349}",
                   run: () => Quickshell.execDetached(["xdg-open", launcher.searchUrl + encodeURIComponent(q)]) })
        return out
    }

    function windowResults() {
        const items = windows.map(w => {
            const entry = DesktopEntries.heuristicLookup(w.app)
            const where = w.ws === "__i3_scratch" ? "scratchpad" : "workspace " + w.ws
            return {
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

    function activate(item, alt) {
        if (!item) return
        if (item.complete !== undefined) {
            input.text = item.complete
            return
        }
        if (item.key) LauncherUsage.record(item.key)
        launcher.visible = false
        item.run(alt)
    }

    function move(delta) {
        if (!results.length) return
        selected = Math.max(0, Math.min(results.length - 1, selected + delta))
    }

    onVisibleChanged: {
        if (!visible) return
        input.text = ""
        selected = 0
        riceProc.running = true
    }

    onModeChanged: {
        if (!visible) return
        if (mode === "windows") treeProc.running = true
        if (mode === "files") recentProc.running = true
    }

    onRestChanged: if (mode === "files" && rest !== "") fdDebounce.restart()

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.visible = !launcher.visible }
        function close(): void { launcher.visible = false }
        // Open with text already typed, e.g. `open "@"` for the window
        // switcher or `open ":theme "`.
        function open(text: string): void {
            launcher.visible = true
            input.text = text
        }
    }

    Process {
        id: riceProc
        command: ["sh", "-c", 'cd "$1" || exit 1\n'
            + 'for d in themes/*/; do [ -f "$d/theme.toml" ] && basename "$d"; done; echo --\n'
            + 'for f in layouts/*.conf; do [ -f "$f" ] && basename "$f" .conf; done; echo --\n'
            + 'head -n1 themes/current 2>/dev/null; echo --\n'
            + 'head -n1 layouts/current 2>/dev/null', "sh", launcher.rice]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split(/^--$/m).map(p => p.split("\n").map(l => l.trim()).filter(l => l))
                launcher.themes = parts[0] || []
                launcher.layouts = parts[1] || []
                launcher.currentTheme = (parts[2] || [])[0] || ""
                launcher.currentLayout = (parts[3] || [])[0] || ""
            }
        }
    }

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
                launcher.windows = out
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
            onStreamFinished: launcher.recentFiles = text.split("\n").filter(l => l)
                .map(p => ({ path: p, dir: p.endsWith("/") }))
        }
    }

    Timer {
        id: fdDebounce
        interval: 120
        onTriggered: launcher.findFiles()
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
                  "--max-results", "400", "--", pattern, launcher.home]
        stdout: StdioCollector {
            onStreamFinished: {
                const q = fdProc.query
                launcher.foundFiles = text.split("\n").filter(l => l)
                    .map(p => {
                        const name = p.replace(/\/$/, "").split("/").pop()
                        const s = Search.match([{ text: name, weight: 1, loose: true },
                                                { text: p, weight: 0.5 }], q)
                        return { path: p, dir: p.endsWith("/"), s: s - p.length * 0.1 }
                    })
                    .filter(f => f.s > -1)
                    .sort((a, b) => b.s - a.s)
                    .slice(0, 50)
                launcher.foundFor = q
            }
        }
        // the query moved on while fd was running
        onExited: if (launcher.rest !== query) launcher.findFiles()
    }

    Column {
        id: body
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Rectangle {
            width: parent.width
            height: 34
            color: Colors.black
            border.color: Colors.dim
            border.width: 1

            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: 6
                anchors.rightMargin: modeLabel.visible ? modeLabel.width + 12 : 6
                color: Colors.neon
                font.family: "monospace"
                font.pixelSize: 14
                clip: true
                onTextChanged: launcher.query = text

                Keys.onPressed: (event) => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    const shift = event.modifiers & Qt.ShiftModifier
                    const item = launcher.results[launcher.selected]
                    if (event.key === Qt.Key_Escape) launcher.visible = false
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) launcher.activate(item, shift)
                    else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) launcher.move(1)
                    else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) launcher.move(-1)
                    else if (event.key === Qt.Key_PageDown) launcher.move(launcher.maxRows)
                    else if (event.key === Qt.Key_PageUp) launcher.move(-launcher.maxRows)
                    else if (event.key === Qt.Key_Backtab) launcher.move(-1)
                    else if (event.key === Qt.Key_Tab) {
                        if (item && item.complete !== undefined) launcher.activate(item, false)
                        else launcher.move(1)
                    }
                    else return
                    event.accepted = true
                }
            }

            MonoText {
                id: modeLabel
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: launcher.mode !== "apps"
                color: Colors.acid
                text: launcher.mode
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(count, launcher.maxRows) * (launcher.rowHeight + spacing)
            visible: count > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: launcher.results
            currentIndex: launcher.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === launcher.selected
                width: ListView.view.width
                height: launcher.rowHeight
                radius: 4
                color: current ? Colors.dim : rowMouse.containsMouse ? Colors.surface : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 10

                    Item {
                        width: 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 28
                            visible: !!row.modelData.icon
                            source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !row.modelData.icon
                            font.pixelSize: 20
                            color: row.current ? Colors.neon : Colors.acid
                            text: row.modelData.glyph || ""
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38
                        spacing: 1

                        MonoText {
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            color: row.current ? Colors.neon : Colors.fg
                            text: row.modelData.title
                        }

                        MonoText {
                            width: parent.width
                            visible: text !== ""
                            elide: Text.ElideMiddle
                            font.pixelSize: 11
                            color: Colors.gray2
                            text: row.modelData.subtitle || ""
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => launcher.activate(row.modelData, mouse.modifiers & Qt.ShiftModifier)
                }
            }
        }

        MonoText {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: 11
            color: Colors.gray2
            text: launcher.footer
        }
    }
}
