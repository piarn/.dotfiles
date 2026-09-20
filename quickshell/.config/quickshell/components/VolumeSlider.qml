// Hand-rolled drag/click slider — shared by VolumeMenu.qml and MicMenu.qml.
// No QtQuick.Controls elsewhere in this shell, so a themed Slider would
// mean fighting its default style rather than just drawing two rectangles.
import QtQuick
import quickshell

Rectangle {
    id: root
    property var audio   // PwNodeAudio — has .volume (0..1+) and .muted

    implicitWidth: 160
    implicitHeight: 8
    radius: height / 2
    color: Colors.dim

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.audio ? root.audio.volume : 0))
        height: parent.height
        radius: parent.radius
        color: root.audio && root.audio.muted ? Colors.red : Colors.neon
    }

    function setFromX(x) {
        if (!root.audio) return
        root.audio.volume = Math.max(0, Math.min(1, x / root.width))
    }

    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => root.setFromX(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) root.setFromX(mouse.x) }
    }
}
