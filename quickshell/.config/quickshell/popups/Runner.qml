// The mini runner ($mod+d): just a search box and a short list — apps,
// most-used first, and the prefix modes (=calc >run /files ?web @windows).
// Same run section and rows as the hub (hub/RunSection.qml, hub/HubRow.qml),
// so it launches and ranks exactly like the hub's apps scope; the hub
// ($mod+space) is the command center around it.
//
// IPC: `qs ipc call launcher toggle`, or `launcher open '@'` to open it
// pre-typed (e.g. a bind straight to the window switcher).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import quickshell
import "../components"
import "../state"
import "hub"

CardWindow {
    id: runner
    visible: false
    centered: true
    needsKeyboard: true
    clickAwayCloses: true
    cardWidth: 560
    cardHeight: body.implicitHeight + 24
    initialFocus: input
    WlrLayershell.namespace: "quickshell-runner"
    onDismissed: runner.visible = false

    readonly property int maxRows: 8

    RunSection { id: run; query: input.text; active: runner.visible }

    property int selected: 0
    readonly property var results: run.results
    onResultsChanged: selected = Math.min(selected, Math.max(results.length - 1, 0))

    function move(delta) {
        if (results.length) selected = Math.max(0, Math.min(results.length - 1, selected + delta))
    }

    function activate(item, alt) {
        if (!item) return
        if (item.key) LauncherUsage.record(item.key)
        runner.visible = false
        item.run(alt)
    }

    onVisibleChanged: if (visible) { input.text = ""; selected = 0 }

    IpcHandler {
        target: "launcher"
        function toggle(): void { runner.visible = !runner.visible }
        function close(): void { runner.visible = false }
        function open(text: string): void {
            runner.visible = true
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
                onTextChanged: runner.selected = 0

                Keys.onPressed: (event) => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    const shift = event.modifiers & Qt.ShiftModifier
                    if (event.key === Qt.Key_Escape) runner.visible = false
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) runner.activate(runner.results[runner.selected], shift)
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) runner.move(1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) runner.move(-1)
                    else if (event.key === Qt.Key_PageDown) runner.move(runner.maxRows)
                    else if (event.key === Qt.Key_PageUp) runner.move(-runner.maxRows)
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
            height: Math.min(count, runner.maxRows) * 40
            visible: count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: runner.results
            currentIndex: runner.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: HubRow {
                required property var modelData
                required property int index
                item: modelData
                current: index === runner.selected
                onClicked: (alt) => runner.activate(modelData, alt)
            }
        }

        MonoText {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: 11
            color: Colors.gray2
            text: run.hint + " · ↑↓ move · esc close"
        }
    }
}
