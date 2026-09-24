// Notification list, opened by clicking the bell widget in Bar.qml. Every
// notification lands here (toasts are just the on-screen subset, see
// NotificationToasts.qml) until dismissed; do-not-disturb lives here and in
// the quick settings panel.
import QtQuick
import quickshell
import "../state"
import "../components"

BarPopup {
    id: menu
    name: "notifications"
    fixedWidth: 360

    Item {
        width: parent.width
        height: dndBtn.implicitHeight

        MonoText {
            anchors.left: parent.left
            color: Colors.gray
            text: "notifications" + (NotificationState.notifications.length ? " · " + NotificationState.notifications.length : "")
        }

        Row {
            anchors.right: parent.right
            spacing: 12

            TextButton {
                id: dndBtn
                label: NotificationState.dnd ? "dnd on" : "dnd off"
                baseColor: NotificationState.dnd ? Colors.red : Colors.acid
                onClicked: NotificationState.toggleDnd()
            }
            TextButton {
                visible: NotificationState.notifications.length > 0
                label: "clear all"
                onClicked: NotificationState.clearAll()
            }
        }
    }

    MonoText {
        visible: NotificationState.notifications.length === 0
        font.pixelSize: 13
        color: Colors.gray
        text: "nothing here"
    }

    // Scrolls once the list outgrows ~70% of the screen.
    Flickable {
        width: parent.width
        height: Math.min(list.implicitHeight, (menu.screen ? menu.screen.height : 1080) * 0.7)
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
