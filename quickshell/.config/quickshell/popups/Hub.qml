// The dots hub: one centered command center for launching things and
// driving the machine and the rice. Opens on a home screen — live status,
// quick toggles, what you use most, your tmux sessions, the focus timer —
// and one search box finds everything else across the scopes:
//
//   apps    apps, plus the prefix modes: =calc >run /files ?web @windows
//   dev     tmux sessions, git projects, ssh hosts        (hub/DevSection)
//   system  network, bluetooth, audio, display, power, session
//   style   rice themes, previewed with wallpaper + palette
//   tools   capture, color picker, focus timer, clipboard, notifications
//
// Typing ranks apps and every scope's rows together, tagged by where they
// live ("night" finds night light, "ember" the theme). A scope or group
// name followed by a space narrows to it: "ssh ", "theme to", "vpn".
// Rows and their kinds are in hub/HubRow.qml.
//
// Keys: ↑↓ / ^j ^k move · enter acts · ←→ nudge a level or pick a quick
// toggle · tab / shift+tab switch scope · backspace on an empty box goes
// back a page · esc closes.
//
// Opened from sway over IPC (a wlroots compositor offers no global
// shortcuts to clients): `qs ipc call hub toggle system`, or `hub open
// system session` to land on a group. The mini runner ($mod+d,
// popups/Runner.qml) is the compact apps-only version.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import quickshell
import "../components"
import "../state"
import "hub"
import "hub/search.js" as Search

CardWindow {
    id: hub
    visible: false
    centered: true
    needsKeyboard: true
    clickAwayCloses: true
    cardWidth: 780
    cardHeight: 520
    initialFocus: input
    title: "dots"
    WlrLayershell.namespace: "quickshell-hub"
    onDismissed: hub.visible = false

    RunSection { id: run; query: hub.query; active: hub.visible }
    DevSection { id: dev }
    SystemSection { id: system; onOpenPopup: (name) => hub.popup(name) }
    StyleSection { id: style }
    ToolsSection { id: tools; onOpenPopup: (name) => hub.popup(name) }

    // "all" is the home screen; the rest filter to one section.
    readonly property var scopes: ["all", "apps", "dev", "system", "style", "tools"]
    readonly property var sectionOf: ({ apps: run, dev: dev, system: system, style: style, tools: tools })
    property int scopeIndex: 0
    readonly property string scope: scopes[scopeIndex]

    property string query: ""
    property var stack: []        // pages opened with Enter: [{title, rows}]
    property int selected: 0
    property int armed: -1        // confirm row waiting for its second Enter
    property int chip: 0          // picked quick toggle on the home screen

    function v(x) { return typeof x === "function" ? x() : x }

    function popup(name) {
        hub.visible = false
        PopupState.toggle(name)
    }

    // ── home ────────────────────────────────────────────────────────────

    function profileName() {
        const p = PowerProfiles.profile
        return p === PowerProfile.PowerSaver ? "saver" : p === PowerProfile.Performance ? "performance" : "balanced"
    }

    readonly property var chips: [
        { title: "wi-fi", on: () => NetworkState.wifiEnabled,
          run: () => NetworkState.setWifiEnabled(!NetworkState.wifiEnabled) },
        { title: "bluetooth", on: () => BluetoothState.powered, run: () => BluetoothState.togglePower() },
        { title: "silence", on: () => NotificationState.dnd, run: () => NotificationState.toggleDnd() },
        { title: "awake", on: () => IdleState.inhibit, run: () => IdleState.inhibit = !IdleState.inhibit },
        { title: "night", on: () => NightLightState.active,
          run: () => { if (NightLightState.available) NightLightState.active = !NightLightState.active } },
        { title: () => hub.profileName(), on: () => PowerProfiles.profile !== PowerProfile.Balanced,
          run: () => {
              const order = [PowerProfile.PowerSaver, PowerProfile.Balanced]
              if (PowerProfiles.hasPerformanceProfile) order.push(PowerProfile.Performance)
              PowerProfiles.profile = order[(order.indexOf(PowerProfiles.profile) + 1) % order.length]
          } },
    ]

    function statusText() {
        const p = NetworkState.primary
        const parts = [!p || !p.connected ? "offline"
            : p.type === "wifi" ? p.connection + " " + p.signal + "%" : p.type]
        const vpns = NetworkState.vpns.filter(v => v.active).map(v => v.name)
            .concat(ExtrasState.vpns.filter(v => v.available && v.active).map(v => v.name.toLowerCase()))
        if (vpns.length) parts.push("vpn " + vpns.join(" "))
        const bt = BluetoothState.connectedDevices
        if (bt.length) parts.push("bt " + bt.map(d => d.name).join(", "))
        const sink = VolumeState.sinkAudio
        if (sink) parts.push("vol " + (sink.muted ? "mute" : Math.round(sink.volume * 100) + "%"))
        const dev = UPower.displayDevice
        if (dev.isLaptopBattery) parts.push("bat " + Math.round(dev.percentage * 100) + "%")
        if (FocusState.running) parts.push("focus " + FocusState.text())
        return parts.join("  ·  ")
    }

    // Everything with a usage key, so the home screen can list what you
    // actually reach for — apps and commands alike.
    function corpus() {
        const out = run.appResults("")
        for (const sec of [dev, system, style, tools])
            for (const item of sec.rows) if (item.key) out.push(item)
        return out
    }

    function homeRows() {
        const recent = corpus()
            .map(item => ({ item, w: LauncherUsage.weight(item.key) }))
            .filter(x => x.w > 0)
            .sort((a, b) => b.w - a.w)
            .slice(0, 6)
            .map(x => x.item)
        const sessions = dev.sessionRows().slice(0, 5)
        const rows = [
            { kind: "status", text: () => hub.statusText() },
            { kind: "chips", chips: hub.chips },
        ]
        if (recent.length) rows.push({ kind: "header", title: "recent" }, ...recent)
        if (sessions.length) rows.push({ kind: "header", title: "sessions" }, ...sessions)
        rows.push({ kind: "header", title: "focus" }, ...tools.focusRows().slice(1))
        return rows
    }

    // ── results ─────────────────────────────────────────────────────────

    // "ssh foo" / "theme" / "dev x": a scope or group name, then a space
    readonly property var narrowed: {
        const m = query.match(/^(\S+)\s+(.*)$/)
        if (!m) return null
        const word = m[1].toLowerCase()
        if (word === "run") return { scope: "apps", rest: m[2] }
        if (sectionOf[word]) return { scope: word, rest: m[2] }
        for (const sec of [dev, system, style, tools])
            if (sec.rows.some(r => r.group === word)) return { group: word, rest: m[2] }
        return null
    }

    // [{item, tag}]
    readonly property var results: {
        let rows
        if (query === "") {
            rows = stack.length ? stack[stack.length - 1].rows()
                : scope === "all" ? homeRows()
                : scope === "apps" ? run.results : sectionOf[scope].rows
            rows = rows.map(item => ({ item, tag: "" }))
        } else if (run.mode !== "apps") {
            rows = run.results.map(item => ({ item, tag: "" }))
        } else if (narrowed) {
            rows = searchAll(narrowed.rest.trim().toLowerCase(), narrowed.scope || scope, narrowed.group)
        } else {
            rows = searchAll(run.rest.toLowerCase(), scope, "")
        }
        return rows.filter(r => !v(r.item.hidden))
    }

    // Apps and every scope's rows (pages included), ranked together. Only
    // static fields are scored — reading live ones here would rebuild the
    // list on every volume tick. Commands match whole words and prefixes
    // only: the scattered-letters match that finds "lbo" → LibreOffice
    // would turn "blue" into "Built-in aUdio … stEreo". An empty q lists
    // the scope/group as is.
    function searchAll(q, inScope, group) {
        const out = []
        const add = (item, tag) => {
            if (["header", "info", "status", "chips"].includes(item.kind)) return
            if (group && item.group !== group) return
            if (q === "") { out.push({ item, tag, s: 0 }); return }
            const s = Search.match([
                { text: item.title, weight: 1 },
                { text: item.aliases || "", weight: 0.8 },
                { text: item.group || "", weight: 0.6 },
            ], q)
            if (s >= 0) out.push({ item, tag, s: s + 20 * Math.log2(1 + LauncherUsage.weight(item.key || "")) })
        }
        if (!group && (inScope === "all" || inScope === "apps"))
            for (const item of run.appResults(q).slice(0, 20)) out.push({ item, tag: "app", s: item.s })
        for (const name of ["dev", "system", "style", "tools"]) {
            if (inScope !== "all" && inScope !== name) continue
            for (const item of sectionOf[name].rows) {
                add(item, name + (item.group && item.group !== item.title ? " · " + item.group : ""))
                // clipboard entries only when asked for by name
                if (item.kind === "page" && item.group !== "clipboard")
                    for (const sub of item.rows()) add(sub, name + " · " + item.title)
            }
        }
        return q === "" ? out : out.sort((a, b) => b.s - a.s).slice(0, 60)
    }

    readonly property string footer: {
        if (query !== "" && run.mode !== "apps") return run.hint
        const where = stack.length ? [scope].concat(stack.map(p => p.title)).join(" › ") + " · ⌫ back · " : ""
        if (query !== "") return where + results.length + " results · enter act · tab scope · esc close"
        if (scope === "all") return "type to search · tab scope · ←→ toggles · enter act · esc close"
        if (scope === "apps") return run.hint + " · tab scope"
        return where + (scope === "system" ? "←→ level · " : "") + "tab scope · enter act · esc close"
    }

    // ── selection ───────────────────────────────────────────────────────

    function selectable(i) {
        const r = results[i]
        return r && r.item.kind !== "header" && r.item.kind !== "status"
    }

    function firstFrom(i, dir) {
        for (let j = i; j >= 0 && j < results.length; j += dir)
            if (selectable(j)) return j
        return -1
    }

    function reselect(i) {
        armed = -1
        let j = firstFrom(Math.max(0, Math.min(i, results.length - 1)), 1)
        if (j < 0) j = firstFrom(results.length - 1, -1)
        selected = Math.max(j, 0)
    }

    function move(delta) {
        armed = -1
        const dir = delta > 0 ? 1 : -1
        const j = Math.max(0, Math.min(results.length - 1, selected + delta))
        const found = firstFrom(j, dir)
        selected = found >= 0 ? found : Math.max(firstFrom(j, -dir), 0)
    }

    // A new query starts at the top — once `results` has caught up with
    // it: this handler runs before the results binding re-evaluates.
    property bool freshQuery: false
    onQueryChanged: freshQuery = true
    onResultsChanged: {
        if (freshQuery) {
            freshQuery = false
            reselect(0)
        } else if (!selectable(selected)) {
            reselect(selected)
        }
    }

    function setScope(i) {
        scopeIndex = (i + scopes.length) % scopes.length
        stack = []
        input.text = ""
        chip = 0
        reselect(0)
    }

    function activate(entry, alt) {
        if (!entry) return
        const item = entry.item
        if (item.key) LauncherUsage.record(item.key)
        switch (item.kind || "action") {
        case "header":
        case "status":
        case "info":
            return
        case "chips":
            item.chips[chip].run()
            return
        case "page":
            stack = stack.concat([{ title: item.title, rows: item.rows }])
            if (item.enter) item.enter()
            input.text = ""
            reselect(0)
            return
        case "toggle":
        case "choice":
        case "level":
            if (item.run) item.run()
            return
        }
        if (item.confirm && armed !== selected) {
            armed = selected
            return
        }
        if (!item.keepOpen) hub.visible = false
        item.run(alt)
    }

    function back() {
        if (!stack.length) return false
        stack = stack.slice(0, -1)
        reselect(0)
        return true
    }

    // Open on a scope, optionally on the first row of a group.
    function show(name, group) {
        const i = scopes.indexOf(name === "run" ? "apps" : name)
        visible = true
        setScope(i >= 0 ? i : 0)
        if (group) {
            const h = results.findIndex(r => r.item.kind === "header" && r.item.title === group)
            if (h >= 0) {
                reselect(h + 1)
                anchorTimer.index = h
                anchorTimer.restart()
            }
        }
    }

    function toggle(name) {
        const want = name === "run" ? "apps" : name || "all"
        if (visible && scope === want) visible = false
        else show(want)
    }

    onVisibleChanged: {
        if (!visible) return
        RiceState.refresh()
        dev.refresh()
    }

    // Scroll a group's header to the top once the list has rebuilt for the
    // new scope (positioning right away hits the old model).
    Timer {
        id: anchorTimer
        property int index: -1
        interval: 30
        onTriggered: list.positionViewAtIndex(index, ListView.Beginning)
    }

    IpcHandler {
        target: "hub"
        function toggle(scope: string): void { hub.toggle(scope) }
        function open(scope: string, group: string): void { hub.show(scope, group) }
        function close(): void { hub.visible = false }
    }


    // ── layout ──────────────────────────────────────────────────────────

    Column {
        x: 12
        y: hub.contentTop
        width: hub.cardWidth - 24
        height: hub.cardHeight - hub.contentTop - 12
        spacing: 8

        Rectangle {
            id: searchBox
            width: parent.width
            height: 38
            color: Colors.black
            border.width: Style.border
            border.color: input.activeFocus ? Colors.neon : Colors.dim

            MonoText {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                font.pixelSize: 14
                color: Colors.gray
                text: hub.scope === "all" ? "search or run anything…" : "search " + hub.scope + "…"
            }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: scopeRow.width + 24
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.neon
                font.family: "monospace"
                font.pixelSize: 14
                clip: true
                onTextChanged: hub.query = text

                Keys.onPressed: (event) => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    const shift = event.modifiers & Qt.ShiftModifier
                    const entry = hub.results[hub.selected]
                    const kind = entry ? entry.item.kind : ""
                    const left = event.key === Qt.Key_Left, right = event.key === Qt.Key_Right
                    if (event.key === Qt.Key_Escape) hub.visible = false
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) hub.activate(entry, shift)
                    else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) hub.move(1)
                    else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) hub.move(-1)
                    else if (event.key === Qt.Key_PageDown) hub.move(8)
                    else if (event.key === Qt.Key_PageUp) hub.move(-8)
                    else if (event.key === Qt.Key_Tab) hub.setScope(hub.scopeIndex + 1)
                    else if (event.key === Qt.Key_Backtab) hub.setScope(hub.scopeIndex - 1)
                    else if (kind === "level" && (left || right)) entry.item.adjust((right ? 1 : -1) / Style.segments)
                    else if (kind === "chips" && (left || right))
                        hub.chip = (hub.chip + (right ? 1 : -1) + entry.item.chips.length) % entry.item.chips.length
                    else if (event.key === Qt.Key_Backspace && input.text === "" && hub.back()) {}
                    else return
                    event.accepted = true
                }
            }

            // scopes: tab cycles, click picks; a prefix mode shows its name
            Row {
                id: scopeRow
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                MonoText {
                    visible: hub.query !== "" && run.mode !== "apps"
                    color: Colors.acid
                    text: run.mode
                }

                Repeater {
                    model: hub.query !== "" && run.mode !== "apps" ? [] : hub.scopes

                    delegate: MonoText {
                        id: scopeLabel
                        required property string modelData
                        required property int index
                        readonly property bool current: index === hub.scopeIndex
                        font.pixelSize: 11
                        font.bold: current
                        color: current ? Colors.neon : scopeMouse.containsMouse ? Colors.fg : Colors.gray
                        text: modelData

                        MouseArea {
                            id: scopeMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hub.setScope(scopeLabel.index)
                        }
                    }
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - searchBox.height - footerText.height - 2 * parent.spacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: hub.results
            currentIndex: hub.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            onModelChanged: Qt.callLater(() => positionViewAtIndex(hub.selected, ListView.Contain))

            delegate: HubRow {
                required property var modelData
                required property int index
                item: modelData.item
                tag: modelData.tag
                current: index === hub.selected
                armed: index === hub.armed
                chip: hub.chip
                onClicked: (alt) => {
                    hub.selected = index
                    hub.activate(modelData, alt)
                }
            }

            MonoText {
                anchors.centerIn: parent
                visible: list.count === 0
                color: Colors.gray
                text: hub.query === "" ? "nothing here" : "nothing matches"
            }
        }

        Item {
            width: parent.width
            height: footerText.height

            MonoText {
                id: footerText
                anchors.left: parent.left
                anchors.right: themeText.left
                anchors.rightMargin: 12
                elide: Text.ElideRight
                font.pixelSize: 11
                color: Colors.gray2
                text: hub.footer
            }
            MonoText {
                id: themeText
                anchors.right: parent.right
                font.pixelSize: 11
                color: Colors.gray
                text: [RiceState.currentTheme, RiceState.currentLayout].filter(s => s).join(" · ")
            }
        }
    }
}
