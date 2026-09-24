// "[label]" text button with hover feedback — the bracketed-action style
// every popup uses, minus the copy-pasted Text+MouseArea pair. Set the
// inherited `enabled` to false to grey it out; the MouseArea follows it.
import QtQuick
import quickshell

Text {
    id: root
    property string label: ""
    property color baseColor: Colors.acid
    signal clicked()

    font.family: "monospace"
    font.pixelSize: 12
    text: "[" + label + "]"
    color: !enabled ? Colors.gray : mouse.containsMouse ? Colors.fg : baseColor

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
