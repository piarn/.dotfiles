// One of the strip's quick icons: a glyph that toggles on click, opens
// something on right click, steps on the wheel, and shows a tooltip under
// itself on hover (a PopupWindow anchored to the icon, so it can leave the
// strip's bounds). Hidden tooltips while the island is grown — the tab
// shows the same things in full.
import Quickshell
import QtQuick
import quickshell
import "../state"
import "../components"

Item {
    id: q

    property alias glyph: icon.text
    property color tint: Colors.gray2
    property string tip: ""
    // tests: show the tooltip without a pointer
    property bool forceTip: false

    signal clicked()
    signal rightClicked()
    signal wheeled(int steps)

    implicitWidth: icon.implicitWidth + 8
    implicitHeight: 24

    Icon {
        id: icon
        anchors.centerIn: parent
        font.pixelSize: 16
        color: mouse.containsMouse ? Colors.fg : q.tint
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => m.button === Qt.RightButton ? q.rightClicked() : q.clicked()
        onWheel: (w) => q.wheeled(w.angleDelta.y > 0 ? 1 : -1)
    }

    PopupWindow {
        id: tipWindow
        // Only grows while shown (resets once hidden): clicking changes the
        // text ("volume 59%" → "muted"), and a shrinking, re-centering
        // tooltip jumps under the pointer.
        property real widest: 0
        anchor.item: q
        anchor.rect.x: q.width / 2 - implicitWidth / 2
        anchor.rect.y: q.height + 10
        visible: q.tip !== "" && (q.forceTip || (mouse.containsMouse && !IslandState.grown))
        readonly property real needed: tipText.implicitWidth + 16
        onVisibleChanged: widest = visible ? needed : 0
        onNeededChanged: if (visible) widest = Math.max(widest, needed)
        implicitWidth: Math.max(widest, needed)
        implicitHeight: tipText.implicitHeight + 10
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Colors.black
            border.width: Style.border
            border.color: Colors.dim

            MonoText {
                id: tipText
                anchors.centerIn: parent
                color: Colors.fg
                text: q.tip
            }
        }
    }
}
