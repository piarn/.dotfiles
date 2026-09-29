// The dots hub: one centered window for launching things and for driving
// the machine and the rice. Sections down the left (popups/hub/*Section),
// one search box on top that searches all of them at once.
//
//   run     apps, plus the prefix modes: =calc >run /files ?web @windows
//   style   rice themes, previewed with wallpaper + palette
//   system  network, bluetooth, audio, display, power, session
//
// Empty box: the current section's rows (or the page opened from one).
// Typing: apps and every section's rows ranked together, tagged by where
// they live — "night" finds night light, "blue" bluetooth, "ember" the
// theme. Rows and their kinds are in hub/HubRow.qml.
//
// Keys: ↑↓ / ^j ^k move · enter acts · ←→ nudge a level · tab / shift+tab
// switch section · backspace on an empty box goes back a page · esc closes.
//
// Opened from sway over IPC (a wlroots compositor offers no global
// shortcuts to clients): `qs ipc call hub toggle system`, or `hub open
// system session` to land on a group. The old `launcher` target still
// works for the run section.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
    cardWidth: 1000
    cardHeight: 640
    initialFocus: input
    title: "dots"
    WlrLayershell.namespace: "quickshell-hub"
    onDismissed: hub.visible = false

    RunSection { id: run; query: hub.query; active: hub.visible }
    StyleSection { id: style }
    SystemSection {
        id: system
        onOpenPopup: (name) => {
            hub.visible = false
            PopupState.toggle(name)
        }
    }

    readonly property var sections: [run, style, system]
    property int sectionIndex: 0
    readonly property var section: sections[sectionIndex]

    property string query: ""
    property var stack: []        // pages opened with Enter: [{title, rows}]
    property int selected: 0
    property int armed: -1        // confirm row waiting for its second Enter

    function v(x) { return typeof x === "function" ? x() : x }

    // [{item, tag}]
    readonly property var results: {
        if (query === "") {
            const rows = stack.length ? stack[stack.length - 1].rows()
                : section === run ? run.results : section.rows
            return rows.map(item => ({ item, tag: "" }))
        }
        if (run.mode !== "apps") return run.results.map(item => ({ item, tag: "" }))
        return searchAll(run.rest.toLowerCase())
    }

    // Apps and every section's rows (pages included), ranked together.
    // Only static fields are scored — reading live ones here would rebuild
    // the list on every volume tick. Settings match whole words and
    // prefixes only: the scattered-letters match that finds "lbo" →
    // LibreOffice would turn "blue" into "Built-in aUdio … stEreo".
    function searchAll(q) {
        const out = run.appResults(q).slice(0, 20).map(item => ({ item, tag: "app", s: item.s }))
        const add = (item, tag) => {
            if (item.kind === "header") return
            const s = Search.match([
                { text: item.title, weight: 1 },
                { text: item.aliases || "", weight: 0.8 },
                { text: item.group || "", weight: 0.6 },
            ], q)
            if (s >= 0) out.push({ item, tag, s })
        }
        for (const sec of [style, system]) {
            for (const item of sec.rows) {
                add(item, sec.name + (item.group && item.group !== item.title ? " · " + item.group : ""))
                if (item.kind === "page") for (const sub of item.rows()) add(sub, sec.name + " · " + item.title)
            }
        }
        return out.sort((a, b) => b.s - a.s).slice(0, 60)
    }

    readonly property string where: [section.name].concat(stack.map(p => p.title)).join(" › ")

    readonly property string footer: {
        if (query !== "" && run.mode !== "apps") return run.hint + " · esc close"
        if (query !== "") return "enter act · ←→ level · ↑↓ move · esc close"
        const nav = "tab section · ↑↓ move · enter act · esc close"
        if (section === run) return run.hint + " · " + nav
        return (stack.length ? "⌫ back · " : "") + "←→ level · " + nav
    }

    function selectable(i) {
        const r = results[i]
        return r && r.item.kind !== "header"
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
        let j = Math.max(0, Math.min(results.length - 1, selected + delta))
        const found = firstFrom(j, dir)
        selected = found >= 0 ? found : Math.max(firstFrom(j, -dir), 0)
    }

    onQueryChanged: reselect(0)
    onResultsChanged: if (!selectable(selected)) reselect(selected)

    function setSection(i) {
        sectionIndex = (i + sections.length) % sections.length
        stack = []
        input.text = ""
        reselect(0)
    }

    function activate(entry, alt) {
        if (!entry) return
        const item = entry.item
        switch (item.kind || "action") {
        case "header":
        case "info":
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
        if (item.key) LauncherUsage.record(item.key)
        hub.visible = false
        item.run(alt)
    }

    function back() {
        if (!stack.length) return false
        stack = stack.slice(0, -1)
        reselect(0)
        return true
    }

    // Open on a section, optionally on the first row of a group.
    function show(name, group) {
        const i = sections.findIndex(s => s.name === name)
        visible = true
        setSection(i >= 0 ? i : 0)
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
        if (visible && (!name || section.name === name)) visible = false
        else show(name || "run")
    }

    onVisibleChanged: if (visible) RiceState.refresh()

    // Scroll a group's header to the top once the list has rebuilt for the
    // new section (positioning right away hits the old model).
    Timer {
        id: anchorTimer
        property int index: -1
        interval: 30
        onTriggered: list.positionViewAtIndex(index, ListView.Beginning)
    }

    IpcHandler {
        target: "hub"
        function toggle(section: string): void { hub.toggle(section) }
        function open(section: string, group: string): void { hub.show(section, group) }
        function close(): void { hub.visible = false }
    }

    // The launcher's old target: $mod+space, and `open '@'`-style binds.
    IpcHandler {
        target: "launcher"
        function toggle(): void { hub.toggle("run") }
        function close(): void { hub.visible = false }
        function open(text: string): void {
            hub.show("run")
            input.text = text
        }
    }

    Column {
        x: 12
        y: hub.contentTop
        width: hub.cardWidth - 24
        height: hub.cardHeight - hub.contentTop - 12
        spacing: 8

        // search
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
                text: "search apps, settings, themes…"
            }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: status.width + 24
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
                    const level = entry && entry.item.kind === "level"
                    if (event.key === Qt.Key_Escape) hub.visible = false
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) hub.activate(entry, shift)
                    else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) hub.move(1)
                    else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) hub.move(-1)
                    else if (event.key === Qt.Key_PageDown) hub.move(8)
                    else if (event.key === Qt.Key_PageUp) hub.move(-8)
                    else if (event.key === Qt.Key_Tab) hub.setSection(hub.sectionIndex + 1)
                    else if (event.key === Qt.Key_Backtab) hub.setSection(hub.sectionIndex - 1)
                    else if (level && event.key === Qt.Key_Left) entry.item.adjust(-1 / Style.segments)
                    else if (level && event.key === Qt.Key_Right) entry.item.adjust(1 / Style.segments)
                    else if (event.key === Qt.Key_Backspace && input.text === "" && hub.back()) {}
                    else return
                    event.accepted = true
                }
            }

            MonoText {
                id: status
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: hub.query !== "" && run.mode !== "apps" ? Colors.acid : Colors.gray
                text: hub.query !== "" && run.mode !== "apps" ? run.mode
                    : [RiceState.currentTheme, RiceState.currentLayout].filter(s => s).join(" · ")
            }
        }

        Row {
            width: parent.width
            height: parent.height - searchBox.height - footerText.height - 2 * parent.spacing

            // sections
            Column {
                width: 150
                height: parent.height
                spacing: 2

                Repeater {
                    model: hub.sections

                    delegate: Rectangle {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool current: index === hub.sectionIndex && hub.query === ""
                        width: parent.width
                        height: 34
                        color: current || tabMouse.containsMouse ? Colors.surface : "transparent"

                        Marker { visible: tab.current }

                        Icon {
                            id: tabIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: tab.current ? Colors.neon : Colors.gray2
                            text: tab.modelData.glyph
                        }
                        MonoText {
                            anchors.left: tabIcon.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 13
                            font.bold: tab.current
                            color: tab.current ? Colors.neon : Colors.fg
                            text: tab.modelData.name
                        }
                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hub.setSection(tab.index)
                        }
                    }
                }
            }

            Item { width: 12; height: 1 }
            Rectangle { width: Style.border; height: parent.height; color: Colors.dim }
            Item { width: 12; height: 1 }

            Column {
                width: parent.width - 150 - 25
                height: parent.height
                spacing: 4

                // where you are: "system › wi-fi networks" or the result count
                MonoText {
                    id: crumb
                    width: parent.width
                    leftPadding: 10
                    font.pixelSize: 11
                    color: Colors.gray2
                    text: hub.query !== "" ? hub.results.length + " results" : hub.where
                }

                ListView {
                    id: list
                    width: parent.width
                    height: parent.height - crumb.height - parent.spacing
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
            }
        }

        MonoText {
            id: footerText
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: 11
            color: Colors.gray2
            text: hub.footer
        }
    }
}
