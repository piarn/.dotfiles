// Speaker and mic popups — one file, instantiated twice from shell.qml
// (`AudioMenu { name: "volume" }` and `AudioMenu { name: "mic"; input: true }`).
// Volume slider on top, output/input device picker below.
import Quickshell.Services.Pipewire
import QtQuick
import quickshell
import "../state"
import "../components"

BarPopup {
    id: menu
    property bool input: false
    // Fixed width because device names can be longer than the slider row;
    // a content-driven width would fight itself between the two.
    fixedWidth: 290

    readonly property var audio: input ? VolumeState.sourceAudio : VolumeState.sinkAudio
    readonly property var nodes: input ? VolumeState.sources : VolumeState.sinks
    readonly property var current: input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink

    Row {
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 18
            color: menu.audio && menu.audio.muted ? Colors.red : Colors.neon
            text: menu.input ? VolumeState.micIcon() : VolumeState.speakerIcon()

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: VolumeState.toggleMute(menu.audio)
            }
        }

        LevelSlider {
            anchors.verticalCenter: parent.verticalCenter
            value: menu.audio ? menu.audio.volume : 0
            muted: menu.audio ? menu.audio.muted : false
            onMoved: (v) => VolumeState.setVolume(menu.input, v)
            onStepped: (d) => VolumeState.adjust(menu.input, d)
        }

        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
            font.bold: true
            color: Colors.neon
            text: menu.audio ? Math.round(menu.audio.volume * 100) + "%" : "—"
        }
    }

    Divider { visible: menu.nodes.length > 0 }

    Column {
        width: parent.width
        spacing: 2
        visible: menu.nodes.length > 0

        Repeater {
            model: menu.nodes

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool active: modelData === menu.current
                width: menu.innerWidth
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
                    onClicked: menu.input ? VolumeState.setSource(row.modelData) : VolumeState.setSink(row.modelData)
                }
            }
        }
    }
}
