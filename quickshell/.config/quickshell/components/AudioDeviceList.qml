// Output or input device picker — the list under the volume/mic rows in
// QuickSettings, opened by the row's chevron. Clicking a device makes it
// the default; the current one is highlighted and checked.
import Quickshell.Services.Pipewire
import QtQuick
import quickshell
import "../state"

Column {
    id: root

    property bool input: false
    readonly property var nodes: input ? VolumeState.sources : VolumeState.sinks
    readonly property var current: input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink

    width: parent ? parent.width : 0
    spacing: 2

    MonoText {
        visible: root.nodes.length === 0
        leftPadding: 6
        color: Colors.gray
        text: root.input ? "no input devices" : "no output devices"
    }

    Repeater {
        model: root.nodes

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool active: modelData === root.current
            width: root.width
            height: 28
            radius: 4
            color: active ? Colors.dim : mouse.containsMouse ? Colors.surface : "transparent"

            MonoText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: row.active ? Colors.neon : Colors.fg
                elide: Text.ElideRight
                text: (row.active ? "\u{f00c} " : "  ") + (row.modelData.description || row.modelData.name)
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.input ? VolumeState.setSource(row.modelData) : VolumeState.setSink(row.modelData)
            }
        }
    }
}
