// The island's clipboard tab: history picker, toggled with `qs ipc call
// clipboard toggle` ($mod+v in sway). History comes from cliphist, which sway feeds
// with `wl-paste --watch cliphist store`. Type to filter, ↑/↓ to move,
// Enter copies the entry back to the clipboard, Delete removes it.
//
// Only entry ids ever go on a command line — the previews can hold
// passwords, and argv is world-readable in /proc.
import Quickshell
import Quickshell.Io
import QtQuick
import quickshell
import "../../components"
import "../../state"
import ".."

Tab {
    id: menu
    name: "clipboard"
    initialFocus: search.input
    spacing: 8

    property var entries: []   // [{id, preview}], newest first
    property string error: ""
    property int selected: 0

    readonly property var matches: {
        const words = search.text.toLowerCase().split(/\s+/).filter(w => w)
        if (!words.length) return entries
        return entries.filter(e => {
            const p = e.preview.toLowerCase()
            return words.every(w => p.includes(w))
        })
    }
    onMatchesChanged: selected = 0

    function copy(entry) {
        if (!entry) return
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist decode | wl-copy", "sh", entry.id])
        menu.close()
    }

    function remove(entry) {
        if (!entry) return
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", entry.id])
        entries = entries.filter(e => e.id !== entry.id)
    }

    onOpened: {
        search.text = ""
        error = ""
        listProc.running = true
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { IslandState.toggle("clipboard") }
        function close(): void { if (menu.shown) menu.close() }
    }

    Process {
        id: listProc
        // through sh so a missing cliphist is a clean exit 127
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 127; exec cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab > 0) out.push({ id: line.slice(0, tab), preview: line.slice(tab + 1) })
                }
                menu.entries = out
            }
        }
        onExited: (code) => {
            if (code === 127) menu.error = "cliphist isn't installed (sudo apt install cliphist)"
            else if (code !== 0) menu.error = "cliphist failed (exit " + code + ")"
        }
    }

    InputField {
        id: search
        width: parent.width
        height: 30
        placeholder: "search clipboard history"
        onAccepted: menu.copy(menu.matches[menu.selected])
        onEscaped: menu.close()
        input.Keys.onDownPressed: menu.selected = Math.min(menu.selected + 1, menu.matches.length - 1)
        input.Keys.onUpPressed: menu.selected = Math.max(menu.selected - 1, 0)
        input.Keys.onDeletePressed: (event) => {
            // Delete removes the selected entry only when the search
            // box is empty — otherwise it edits the query as usual.
            if (search.text === "") menu.remove(menu.matches[menu.selected])
            else event.accepted = false
        }
    }

    MonoText {
        visible: menu.error !== "" || (menu.matches.length === 0 && !listProc.running)
        color: Colors.gray
        text: menu.error || (menu.entries.length ? "nothing matches" : "clipboard history is empty")
    }

    ListView {
        id: list
        width: parent.width
        height: Math.min(contentHeight, 12 * 30)
        visible: count > 0
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: menu.matches
        currentIndex: menu.selected
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 28
            color: index === menu.selected || rowMouse.containsMouse ? Colors.surface : "transparent"

            Marker { visible: row.index === menu.selected }

            MonoText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                color: row.index === menu.selected ? Colors.neon : Colors.fg
                // one line: previews keep their newlines/tabs
                text: row.modelData.preview.replace(/\s+/g, " ")
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menu.copy(row.modelData)
            }
        }
    }

    MonoText {
        font.pixelSize: 11
        color: Colors.gray2
        text: "enter copy · del remove (empty search) · esc close"
    }
}
