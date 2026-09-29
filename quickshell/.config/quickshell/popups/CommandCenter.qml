// The command center ($mod+d): a search box and a short list — apps,
// most-used first, and the prefix modes (=calc >run /files ?web @windows
// ~dev !tools :session). Rows and the mode-dispatch logic live in
// commandcenter/RunSection.qml, commandcenter/ResultRow.qml.
// DevSection/ToolsSection feed RunSection's ~/! modes.
//
// IPC: `qs ipc call commandcenter toggle`, or `commandcenter open '@'` to
// open it pre-typed (e.g. a bind straight to the window switcher).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import quickshell
import "../components"
import "../state"
import "commandcenter"

CardWindow {
    id: cc
    visible: false
    centered: true
    needsKeyboard: true
    clickAwayCloses: true
    cardWidth: 560
    cardHeight: body.implicitHeight + 24
    initialFocus: input
    WlrLayershell.namespace: "quickshell-commandcenter"
    onDismissed: cc.visible = false

    readonly property int maxRows: 8

    DevSection { id: dev }
    ToolsSection { id: tools; onOpenPopup: (name) => cc.popup(name) }
    RunSection {
        id: run
        query: input.text
        active: cc.visible
        devRows: dev.rows
        toolRows: tools.rows
        onOpenPopup: (name) => cc.popup(name)
    }

    property int selected: 0
    property int armed: -1        // confirm row waiting for its second Enter
    readonly property var results: run.results
    onResultsChanged: selected = Math.min(selected, Math.max(results.length - 1, 0))

    function move(delta) {
        armed = -1
        if (results.length) selected = Math.max(0, Math.min(results.length - 1, selected + delta))
    }

    function popup(name) {
        cc.visible = false
        PopupState.toggle(name)
    }

    function activate(item, alt) {
        if (!item) return
        if (item.kind === "toggle" || item.kind === "choice" || item.kind === "level") {
            if (item.run) item.run()
            return
        }
        if (item.confirm && armed !== selected) {
            armed = selected
            return
        }
        armed = -1
        if (item.key) LauncherUsage.record(item.key)
        if (!item.keepOpen) cc.visible = false
        item.run(alt)
    }

    onVisibleChanged: {
        if (!visible) return
        input.text = ""
        selected = 0
        armed = -1
        dev.refresh()
    }

    IpcHandler {
        target: "commandcenter"
        function toggle(): void { cc.visible = !cc.visible }
        function close(): void { cc.visible = false }
        function open(text: string): void {
            cc.visible = true
            input.text = text
        }
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
            border.width: Style.border
            border.color: Colors.dim

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: modeLabel.visible ? modeLabel.width + 20 : 10
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.neon
                font.family: "monospace"
                font.pixelSize: 14
                clip: true
                onTextChanged: { cc.selected = 0; cc.armed = -1 }

                Keys.onPressed: (event) => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    const shift = event.modifiers & Qt.ShiftModifier
                    if (event.key === Qt.Key_Escape) cc.visible = false
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) cc.activate(cc.results[cc.selected], shift)
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) cc.move(1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) cc.move(-1)
                    else if (event.key === Qt.Key_PageDown) cc.move(cc.maxRows)
                    else if (event.key === Qt.Key_PageUp) cc.move(-cc.maxRows)
                    else return
                    event.accepted = true
                }
            }

            MonoText {
                id: modeLabel
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: run.mode !== "apps"
                color: Colors.acid
                text: run.mode
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(count, cc.maxRows) * 34
            visible: count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: cc.results
            currentIndex: cc.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: ResultRow {
                required property var modelData
                required property int index
                item: modelData
                current: index === cc.selected
                armed: index === cc.armed
                tag: modelData.group || ""
                onClicked: (alt) => cc.activate(modelData, alt)
            }
        }

        MonoText {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: 11
            color: Colors.gray2
            text: run.hint + " · ↑↓/^j^k move · esc close"
        }
    }
}
