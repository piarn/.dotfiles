// Bluetooth popup, opened by clicking the bluetooth widget in Bar.qml or
// the › on the quick settings tile. Rows are live BluetoothDevice objects
// (see state/BluetoothState.qml), so connect/pair progress shows without
// any refresh.
import QtQuick
import quickshell
import "../state"
import "../components"

BarPopup {
    id: menu
    name: "bluetooth"
    fixedWidth: 320

    onOpened: BluetoothState.scan()

    Item {
        width: parent.width
        height: powerLabel.implicitHeight

        Row {
            anchors.left: parent.left
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                color: BluetoothState.powered ? Colors.neon : Colors.red
                text: BluetoothState.powered ? "\u{f00af}" : "\u{f00b2}"
            }
            MonoText {
                id: powerLabel
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 13
                font.bold: true
                color: BluetoothState.powered ? Colors.neon : Colors.red
                text: !BluetoothState.available ? "no adapter"
                    : BluetoothState.powered ? "bluetooth on" : "bluetooth off"
            }
        }
        TextButton {
            anchors.right: parent.right
            visible: BluetoothState.available
            label: BluetoothState.powered ? "turn off" : "turn on"
            onClicked: BluetoothState.togglePower()
        }
    }

    Divider {}

    Item {
        width: parent.width
        height: scanBtn.implicitHeight
        visible: BluetoothState.powered

        MonoText {
            anchors.left: parent.left
            color: Colors.gray
            text: BluetoothState.scanning ? "devices · scanning…" : "devices"
        }
        TextButton {
            id: scanBtn
            anchors.right: parent.right
            label: "scan"
            enabled: !BluetoothState.scanning
            onClicked: BluetoothState.scan()
        }
    }

    MonoText {
        width: parent.width
        visible: BluetoothState.powered && BluetoothState.devices.length === 0
        color: Colors.gray
        text: BluetoothState.scanning ? "looking for devices…" : "no devices — try [scan]"
    }

    MonoText {
        width: parent.width
        visible: BluetoothState.available && !BluetoothState.powered
        color: Colors.gray
        wrapMode: Text.Wrap
        text: "turn bluetooth on to see devices"
    }

    Column {
        width: parent.width
        spacing: 2
        visible: BluetoothState.powered

        Repeater {
            model: BluetoothState.devices

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property string status: BluetoothState.stateText(modelData)
                width: menu.innerWidth
                height: 34
                radius: 4
                color: modelData.connected ? Colors.dim : "transparent"

                Icon {
                    id: devIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: row.modelData.connected ? Colors.neon : row.modelData.paired ? Colors.fg : Colors.gray
                    text: BluetoothState.icon(row.modelData)
                }

                Column {
                    anchors.left: devIcon.right
                    anchors.right: actions.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    MonoText {
                        width: parent.width
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        color: row.modelData.connected ? Colors.neon : row.modelData.paired ? Colors.fg : Colors.gray2
                        text: row.modelData.name || row.modelData.address
                    }
                    MonoText {
                        width: parent.width
                        visible: text !== ""
                        font.pixelSize: 11
                        color: Colors.gray2
                        text: row.status
                            || (row.modelData.connected && row.modelData.batteryAvailable
                                ? "battery " + Math.round(row.modelData.battery * 100) + "%" : "")
                    }
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // For stale pairings (bluez "br-connection-key-missing"):
                    // connect keeps failing until the device is removed and
                    // re-paired from scratch.
                    TextButton {
                        visible: row.modelData.paired && !row.modelData.connected
                        label: "forget"
                        baseColor: Colors.gray
                        enabled: !BluetoothState.busy(row.modelData)
                        onClicked: row.modelData.forget()
                    }
                    TextButton {
                        label: row.modelData.connected ? "disconnect" : row.modelData.paired ? "connect" : "pair"
                        enabled: !BluetoothState.busy(row.modelData)
                        onClicked: {
                            if (row.modelData.connected) row.modelData.disconnect()
                            else if (row.modelData.paired) row.modelData.connect()
                            else BluetoothState.pair(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
