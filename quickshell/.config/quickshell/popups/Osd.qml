// Volume / mic / brightness OSD, in the shape of the classic macOS one: a
// rounded square low in the middle of the focused screen, a big glyph, and
// 16 segments underneath. Click-through (empty input mask) and never takes
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

    readonly property int segments: 16
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
    implicitWidth: 200
    implicitHeight: 200
    mask: Region {}

    function glyph() {
        const v = OsdState.value
        if (OsdState.kind === "brightness") return v < 0.34 ? "\u{f00de}" : v < 0.67 ? "\u{f00df}" : "\u{f00e0}"
        if (OsdState.kind === "mic") return OsdState.muted ? "\u{f036d}" : "\u{f036c}"
        if (OsdState.muted) return "\u{f075f}"
        if (v <= 0) return "\u{f0581}"
        return v < 0.34 ? "\u{f057f}" : v < 0.67 ? "\u{f0580}" : "\u{f057e}"
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 22
        color: Qt.rgba(Colors.black.r, Colors.black.g, Colors.black.b, 0.88)
        border.width: 1
        border.color: Colors.dim
        opacity: OsdState.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: OsdState.shown ? 90 : 350; easing.type: Easing.OutQuad } }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 34
            font.pixelSize: 92
            color: OsdState.muted ? Colors.red : Colors.fg
            text: root.glyph()
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            spacing: 2

            Repeater {
                model: root.segments

                delegate: Rectangle {
                    required property int index
                    width: 9
                    height: 7
                    radius: 1
                    color: index < root.filled ? Colors.neon : Colors.dim
                }
            }
        }
    }
}
