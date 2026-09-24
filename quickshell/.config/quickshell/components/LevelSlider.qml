// Hand-rolled drag/click slider (0..1). No QtQuick.Controls elsewhere in
// this shell, so a themed Slider would mean fighting its default style
// rather than just drawing two rectangles. Emits moved(v) while dragging
// and stepped(±step) on the wheel;
// the owner writes it wherever it belongs (wpctl, backlight).
import QtQuick
import quickshell

Rectangle {
    id: root
    property real value: 0
    property bool muted: false
    signal moved(real v)
    // wheel: ±step, applied relative to the owner's own latest target — the
    // bound value can trail behind rapid scrolling
    signal stepped(real delta)
    property real step: 0.05

    implicitWidth: 160
    implicitHeight: 8
    radius: height / 2
    color: Colors.dim

    // While dragging, draw where the pointer is rather than the bound value,
    // which trails behind whatever process applies the change.
    property real dragValue: 0
    readonly property real shown: mouse.pressed ? dragValue : value

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.shown))
        height: parent.height
        radius: parent.radius
        color: root.muted ? Colors.red : Colors.neon
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        function emit(x) {
            root.dragValue = Math.max(0, Math.min(1, (x - 6) / root.width))
            root.moved(root.dragValue)
        }
        onPressed: (mouse) => emit(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) emit(mouse.x) }
        onWheel: (wheel) => root.stepped(wheel.angleDelta.y > 0 ? root.step : -root.step)
    }
}
