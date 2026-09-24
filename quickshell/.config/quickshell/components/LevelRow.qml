// Icon + slider + percentage — the volume/mic/brightness rows in
// QuickSettings. Left-clicking the icon or middle-clicking anywhere on the
// row emits toggled (mute for audio rows); the wheel over the slider emits
// stepped(±delta).
import QtQuick
import quickshell

Item {
    id: root

    property string icon: ""
    property real value: 0
    property bool muted: false
    signal moved(real v)
    signal stepped(real delta)
    signal toggled()

    width: parent ? parent.width : 0
    height: 22

    // Middle clicks only; left clicks/drags belong to the slider on top.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: root.toggled()
    }

    Icon {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        font.pixelSize: 17
        color: root.muted ? Colors.red : Colors.neon
        text: root.icon

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }

    LevelSlider {
        anchors.left: glyph.right
        anchors.right: pct.left
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        muted: root.muted
        onMoved: (v) => root.moved(v)
        onStepped: (d) => root.stepped(d)
    }

    MonoText {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
    }
}
