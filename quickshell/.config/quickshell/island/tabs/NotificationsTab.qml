// The island's notifications tab: every notification until dismissed
// (toasts are just the on-screen subset, see NotificationToasts.qml), with
// silence (do-not-disturb) and clear all. Opened from the island's ● or
// `qs ipc call popup toggle notifications`.
import QtQuick
import quickshell
import "../../state"
import "../../components"
import ".."

Tab {
    id: menu
    name: "notifications"


    // title, then its buttons on their own line
    MonoText {
        color: Colors.gray
        text: "notifications" + (NotificationState.notifications.length ? " · " + NotificationState.notifications.length : "")
    }

    Row {
        spacing: 12

        // do-not-disturb: hides toasts; critical ones still break through
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
        font.pixelSize: 13
        color: Colors.gray
        text: "nothing here"
    }

    // Scrolls once the list outgrows half the screen.
    Flickable {
        width: parent.width
        height: Math.min(list.implicitHeight, (menu.screen ? menu.screen.height : 1080) * 0.5)
        visible: NotificationState.notifications.length > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 6

            Repeater {
                // newest first
                model: NotificationState.notifications.slice().reverse()

                delegate: NotificationCard {
                    required property var modelData
                    width: list.width
                    notification: modelData
                }
            }
        }
    }
}
