// Microphone volume popup, opened by clicking the mic widget in Bar.qml.
// Same layout as VolumeMenu.qml, pointed at defaultAudioSource instead.
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: menu
    visible: VolumeState.micMenuOpen
    // See NetworkMenu.qml's comment on this — Exclusive instead of the
    // on-demand "focusable: true" so Escape closes this immediately.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins.top: 28

    onVisibleChanged: {
        if (visible) Qt.callLater(() => catcher.forceActiveFocus())
    }

    MouseArea {
        anchors.fill: parent
        onClicked: VolumeState.micMenuOpen = false
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: VolumeState.micMenuOpen = false
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 10
        // See VolumeMenu.qml's comment on this — fixed width so the device
        // list and the slider row don't fight over sizing.
        width: 280
        height: content.implicitHeight + 24
        color: Colors.black
        border.color: Colors.neon
        border.width: 2
        radius: 6

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Row {
                id: sliderRow
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 18
                    color: VolumeState.sourceAudio && VolumeState.sourceAudio.muted ? Colors.red : Colors.neon
                    text: VolumeState.micIcon()

                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (VolumeState.sourceAudio) VolumeState.sourceAudio.muted = !VolumeState.sourceAudio.muted
                    }
                }

                VolumeSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    audio: VolumeState.sourceAudio
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: "monospace"
                    font.pixelSize: 13
                    font.bold: true
                    color: Colors.neon
                    text: VolumeState.sourceAudio ? Math.round(VolumeState.sourceAudio.volume * 100) + "%" : "—"
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.dim
                visible: VolumeState.sources.length > 0
            }

            Column {
                id: deviceList
                width: parent.width
                spacing: 2
                visible: VolumeState.sources.length > 0

                Repeater {
                    model: VolumeState.sources

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: modelData === Pipewire.defaultAudioSource
                        width: deviceList.width
                        height: 28
                        radius: 4
                        color: active ? Colors.dim : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "monospace"
                            font.pixelSize: 12
                            color: active ? Colors.neon : Colors.fg
                            elide: Text.ElideRight
                            text: (active ? "\u{f00c} " : "  ") + (modelData.description || modelData.name)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: VolumeState.setSource(modelData)
                        }
                    }
                }
            }
        }
    }
}
