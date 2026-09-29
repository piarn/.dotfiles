// Hand-rolled drag/click level bar (0..1), drawn as Style.segments blocks —
// the same 16 steps as the volume OSD, so the two read as one control. No
// QtQuick.Controls elsewhere in this shell, so a themed Slider would mean
// fighting its default style. Emits moved(v) while dragging and
// stepped(±step) on the wheel; the owner writes it wherever it belongs
// (wpctl, backlight).
import QtQuick
import quickshell

Item {
    id: root
    property real value: 0
    property bool muted: false
    signal moved(real v)
    // wheel: ±step, applied relative to the owner's own latest target — the
    // bound value can trail behind rapid scrolling
    signal stepped(real delta)
    property real step: 0.05

    implicitWidth: 160
    implicitHeight: 10

    // While dragging, draw where the pointer is rather than the bound value,
    // which trails behind whatever process applies the change.
    property real dragValue: 0
    readonly property real shown: Math.max(0, Math.min(1, mouse.pressed ? dragValue : value))

    Row {
        id: row
        anchors.fill: parent
        spacing: 2
        readonly property real cell: (width - spacing * (Style.segments - 1)) / Style.segments

        Repeater {
            model: Style.segments

            delegate: Rectangle {
                required property int index
                // How much of this segment the level covers, 0..1 — the
                // last lit one fills partially so 35% doesn't read as 37.5%.
                readonly property real lit: Math.max(0, Math.min(1, root.shown * Style.segments - index))
                width: row.cell
                height: row.height
                color: Colors.dim

                Rectangle {
                    width: parent.width * parent.lit
                    height: parent.height
                    color: root.muted ? Colors.red : Colors.neon
                }
            }
        }
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
