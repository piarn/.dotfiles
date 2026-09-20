// Bluetooth popup, opened by clicking the bluetooth widget in Bar.qml.
// Same pattern as NetworkMenu.qml: a shared singleton (BluetoothState, from
// ../state) both files read/toggle directly, no IPC needed.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"

PanelWindow {
    id: menu
    visible: BluetoothState.menuOpen
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
    // See NetworkMenu.qml's comment on this — keeps the bar clickable
    // underneath while this popup is open.
    margins.top: 28

    onVisibleChanged: {
        if (visible) {
            BluetoothState.refresh()
            Qt.callLater(() => catcher.forceActiveFocus())
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: BluetoothState.menuOpen = false
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: BluetoothState.menuOpen = false
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 10
        width: 300
        color: Colors.black
        border.color: Colors.neon
        border.width: 2
        radius: 6
        height: content.implicitHeight + 24

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Item {
                width: parent.width
                height: powerLabel.implicitHeight

                Row {
                    anchors.left: parent.left
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                        color: BluetoothState.powered ? Colors.neon : Colors.red
                        text: BluetoothState.powered ? "\u{f00af}" : "\u{f00b2}"
                    }
                    Text {
                        id: powerLabel
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: "monospace"
                        font.pixelSize: 13
                        font.bold: true
                        color: BluetoothState.powered ? Colors.neon : Colors.red
                        text: BluetoothState.powered ? "bluetooth on" : "bluetooth off"
                    }
                }
                Text {
                    anchors.right: parent.right
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.acid
                    text: BluetoothState.powered ? "[turn off]" : "[turn on]"
                    MouseArea { anchors.fill: parent; onClicked: BluetoothState.togglePower() }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.dim }

            Item {
                width: parent.width
                height: scanLabel.implicitHeight
                visible: BluetoothState.powered

                Text {
                    anchors.left: parent.left
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.gray
                    text: BluetoothState.scanning ? "scanning…" : "devices"
                }
                Text {
                    id: scanLabel
                    anchors.right: parent.right
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: BluetoothState.scanning ? Colors.gray : Colors.acid
                    text: "[scan]"
                    MouseArea {
                        anchors.fill: parent
                        enabled: !BluetoothState.scanning
                        onClicked: BluetoothState.scan()
                    }
                }
            }

            Text {
                width: parent.width
                visible: BluetoothState.powered && BluetoothState.devices.length === 0
                font.family: "monospace"
                font.pixelSize: 12
                color: Colors.gray
                text: "no devices — try [scan]"
            }

            Text {
                width: parent.width
                visible: !BluetoothState.powered
                font.family: "monospace"
                font.pixelSize: 12
                color: Colors.gray
                text: "turn bluetooth on to see devices"
                wrapMode: Text.Wrap
            }

            Column {
                width: parent.width
                spacing: 2
                visible: BluetoothState.powered

                Repeater {
                    model: BluetoothState.devices

                    delegate: Rectangle {
                        required property var modelData
                        width: content.width
                        height: 32
                        radius: 4
                        color: modelData.connected ? Colors.dim : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.right: actions.left
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "monospace"
                            font.pixelSize: 13
                            color: modelData.connected ? Colors.neon : (modelData.paired ? Colors.fg : Colors.gray)
                            elide: Text.ElideRight
                            text: (modelData.connected ? "🔗 " : "  ") + modelData.name
                        }

                        Row {
                            id: actions
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // Only offered when paired-but-not-connected: a
                            // link key gone stale (bluez error
                            // "br-connection-key-missing") makes connect()
                            // fail forever until the device is removed and
                            // re-paired from scratch.
                            Text {
                                visible: modelData.paired && !modelData.connected
                                font.family: "monospace"
                                font.pixelSize: 12
                                color: Colors.gray
                                text: "[forget]"
                                MouseArea { anchors.fill: parent; onClicked: BluetoothState.forget(modelData.mac) }
                            }

                            Text {
                                font.family: "monospace"
                                font.pixelSize: 12
                                color: Colors.acid
                                text: modelData.connected ? "[disconnect]" : (modelData.paired ? "[connect]" : "[pair]")

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (modelData.connected) BluetoothState.disconnectFrom(modelData.mac)
                                        else if (modelData.paired) BluetoothState.connectTo(modelData.mac)
                                        else BluetoothState.pair(modelData.mac)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: BluetoothState.actionStatus !== ""
                font.family: "monospace"
                font.pixelSize: 12
                color: BluetoothState.actionStatus.startsWith("failed") ? Colors.red : Colors.acid
                text: BluetoothState.actionStatus
                wrapMode: Text.Wrap
            }
        }
    }
}
