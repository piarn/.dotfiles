// The island's notifications tab: every notification until dismissed
// (toasts are just the on-screen subset, see NotificationToasts.qml),
// grouped by app, newest first, as rows like the network tab's
// (NotificationRow). The header holds silence (do-not-disturb: hides
// toasts, critical ones still break through) and clear all; each app's
// line clears just that app. Keys: ↑/↓ or j/k select, Enter runs the
// default action, Delete dismisses. Opened from the island's ● or
// `qs ipc call popup toggle notifications`.
import QtQuick
import quickshell
import "../../state"
import "../../components"
import ".."
import "../format.js" as Fmt

Tab {
    id: menu
    name: "notifications"
    spacing: 8

    // newest first, then grouped by app in the order apps last notified
    readonly property var newest: NotificationState.notifications.slice().reverse()
    readonly property var groups: Fmt.groupBy(newest, n => n.appName || "other")
    // the same order flattened, for keyboard selection
    readonly property var flat: [].concat(...groups.map(g => g.items))
    property int selected: -1
    property real now: Date.now()

    onFlatChanged: if (selected >= flat.length) selected = flat.length - 1
    onOpened: {
        selected = -1
        now = Date.now()
    }

    Timer {
        running: menu.shown
        interval: 30 * 1000
        repeat: true
        onTriggered: menu.now = Date.now()
    }

    function handleKey(event) {
        const n = flat.length
        if (!n) return false
        if (event.key === Qt.Key_Down || event.key === Qt.Key_J) selected = Math.min(n - 1, selected + 1)
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) selected = Math.max(0, selected - 1)
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && selected >= 0)
            NotificationState.invokeDefault(flat[selected])
        else if (event.key === Qt.Key_Delete && selected >= 0) NotificationState.dismiss(flat[selected])
        else return false
        return true
    }

    SectionHeader {
        title: "notifications"
        count: String(NotificationState.notifications.length)

        TextButton {
            label: NotificationState.dnd ? "silenced" : "silence"
            baseColor: NotificationState.dnd ? Colors.red : Colors.acid
            onClicked: NotificationState.toggleDnd()
        }
        TextButton {
            visible: NotificationState.notifications.length > 0
            label: "clear all"
            onClicked: NotificationState.clearAll()
        }
    }

    MonoText {
        visible: NotificationState.notifications.length === 0
        color: Colors.gray
        text: NotificationState.dnd ? "nothing here · silenced" : "nothing here"
    }

    Repeater {
        model: menu.groups

        delegate: Column {
            id: group
            required property var modelData
            width: menu.width
            spacing: 2

            Divider {}

            SectionHeader {
                title: group.modelData.key.toLowerCase()
                count: group.modelData.items.length > 1 ? String(group.modelData.items.length) : ""

                TextButton {
                    label: "clear"
                    onClicked: { for (const n of group.modelData.items.slice()) NotificationState.dismiss(n) }
                }
            }

            Repeater {
                model: group.modelData.items

                delegate: NotificationRow {
                    required property var modelData
                    width: group.width
                    notification: modelData
                    now: menu.now
                    current: menu.selected >= 0 && menu.flat.indexOf(modelData) === menu.selected
                }
            }
        }
    }

    MonoText {
        visible: NotificationState.notifications.length > 0
        font.pixelSize: 11
        color: Colors.gray2
        text: "↑↓/jk select · enter open · del dismiss · click open"
    }
}
