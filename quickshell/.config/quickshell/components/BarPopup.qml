// Shared shell for every bar popup: a CardWindow in the top-right corner
// whose visibility and output come from PopupState, so it opens on the
// monitor whose bar was clicked. Clicking another window or pressing Escape
// closes it (see CardWindow); clicks on the bar itself are handled by
// Bar.qml. Declare content as children — they go into a Column:
//
//   BarPopup {
//       name: "battery"          // PopupState key, what the bar toggles
//       fixedWidth: 300          // 0 = size to content
//       MonoText { text: "…" }
//   }
import Quickshell.Wayland
import QtQuick
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
    cardHeight: body.implicitHeight + 24

    onVisibleChanged: if (visible) opened()
    onDismissed: close()

    Column {
        id: body
        x: 12
        y: 12
        width: root.fixedWidth > 0 ? root.fixedWidth - 24 : implicitWidth
        spacing: 10
    }
}
