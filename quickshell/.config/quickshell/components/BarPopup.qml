// Shared shell for every bar popup: a CardWindow in the top-right corner
// whose visibility and output come from PopupState, so it opens on the
// monitor whose bar was clicked. Clicking another window or pressing Escape
// closes it (see CardWindow); clicks on the bar itself are handled by
// Bar.qml. Opened from another popup (PopupState.backTo), it starts with a
// ‹ back link. Declare content as children — they go into a Column:
//
//   BarPopup {
//       name: "battery"          // PopupState key, what the bar toggles
//       fixedWidth: 300          // 0 = size to content
//       MonoText { text: "…" }
//   }
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"

CardWindow {
    id: root

    required property string name
    property int fixedWidth: 320
    default property alias content: body.data
    readonly property int innerWidth: body.width

    signal opened()

    function close() { PopupState.close() }

    visible: PopupState.current === name
    screen: PopupState.screen
    WlrLayershell.namespace: "quickshell-popup"
    cardWidth: fixedWidth > 0 ? fixedWidth : body.implicitWidth + 24
    cardHeight: body.implicitHeight + contentTop + 12
    title: name === "quicksettings" ? "quick settings" : name

    onVisibleChanged: if (visible) opened()
    onDismissed: close()

    Column {
        id: body
        x: 12
        y: root.contentTop
        width: root.fixedWidth > 0 ? root.fixedWidth - 24 : implicitWidth
        spacing: 10

        // "‹ quick settings" when opened from another popup's ›.
        Item {
            visible: PopupState.backTo !== "" && PopupState.backTo !== root.name
            width: backRow.implicitWidth
            height: visible ? backRow.implicitHeight : 0

            Row {
                id: backRow
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    color: backMouse.containsMouse ? Colors.fg : Colors.gray2
                    text: "\u{f0141}"
                }
                MonoText {
                    anchors.verticalCenter: parent.verticalCenter
                    color: backMouse.containsMouse ? Colors.fg : Colors.gray2
                    text: PopupState.backTo.replace("quicksettings", "quick settings")
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: PopupState.back()
            }
        }
    }
}
