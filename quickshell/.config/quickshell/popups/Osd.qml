// Volume / mic / brightness OSD: a slim square-framed strip low in the
// middle of the focused screen — glyph, 16 segments (the same bar as quick
// settings' sliders), percentage. Click-through (empty input mask) and never takes
// focus; fades out 1.5s after the last change. What it shows comes from
// state/OsdState.qml.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: root

    readonly property int segments: Style.segments
    readonly property int filled: OsdState.muted ? 0 : Math.round(Math.min(1, OsdState.value) * segments)

    visible: card.opacity > 0
    screen: OsdState.screen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors.bottom: true
    margins.bottom: screen ? Math.round(screen.height * 0.12) : 120
    implicitWidth: 300
    implicitHeight: 40
    mask: Region {}

    function glyph() {
        const v = OsdState.value
        if (OsdState.kind === "brightness") return v < 0.34 ? "\u{e1ad}" : v < 0.67 ? "\u{e1ae}" : "\u{e1ac}"
        if (OsdState.kind === "mic") return OsdState.muted ? "\u{e02b}" : "\u{e31d}"
        if (OsdState.muted) return "\u{e04f}"   // volume_off
        if (v <= 0) return "\u{e04e}"           // volume_mute
        return v < 0.34 ? "\u{e04d}" : v < 0.67 ? "\u{e79c}" : "\u{e050}"
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Style.radius
        color: Qt.rgba(Colors.black.r, Colors.black.g, Colors.black.b, 0.92)
        border.width: Style.border
        border.color: Colors.dim
        opacity: OsdState.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: OsdState.shown ? Style.fast : 300; easing.type: Easing.OutQuad } }

        Icon {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 18
            color: OsdState.muted ? Colors.red : Colors.neon
            text: root.glyph()
        }

        Row {
            id: bar
            anchors.left: glyph.right
            anchors.right: pct.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            readonly property real cell: (width - spacing * (root.segments - 1)) / root.segments

            Repeater {
                model: root.segments

                delegate: Rectangle {
                    required property int index
                    width: bar.cell
                    height: 10
                    color: index < root.filled ? (OsdState.muted ? Colors.red : Colors.neon) : Colors.dim
                }
            }
        }

        MonoText {
            id: pct
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            horizontalAlignment: Text.AlignRight
            color: OsdState.muted ? Colors.red : Colors.fg
            text: OsdState.muted ? "mute" : Math.round(Math.min(1, OsdState.value) * 100) + "%"
        }
    }
}
