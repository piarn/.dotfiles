// The network popup's bluetooth section (it used to be its own popup):
// power, [scan], and the device list. Rows are live BluetoothDevice
// objects (see state/BluetoothState.qml), so connect/pair progress shows
// without any refresh. Scrolls past 6 devices, since a scan can turn up
// a lot of unpaired ones nearby.
import QtQuick
import quickshell
import "../state"

Column {
    id: root
    spacing: 2

    Item {
        width: parent.width
        height: powerBtn.implicitHeight + 4

        MonoText {
            anchors.left: parent.left
            color: BluetoothState.available && !BluetoothState.powered ? Colors.red : Colors.gray
            text: !BluetoothState.available ? "bluetooth · no adapter"
                : !BluetoothState.powered ? "bluetooth is off"
                : BluetoothState.scanning ? "bluetooth · scanning…" : "bluetooth"
        }
        Row {
            anchors.right: parent.right
            spacing: 10

            TextButton {
                visible: BluetoothState.powered
                label: "scan"
                enabled: !BluetoothState.scanning
                onClicked: BluetoothState.scan()
            }
            TextButton {
                id: powerBtn
                visible: BluetoothState.available
                label: BluetoothState.powered ? "turn off" : "turn on"
                baseColor: BluetoothState.powered ? Colors.acid : Colors.red
                onClicked: BluetoothState.togglePower()
            }
        }
    }

    MonoText {
        visible: BluetoothState.powered && BluetoothState.devices.length === 0
        leftPadding: 6
        color: Colors.gray
        text: BluetoothState.scanning ? "looking for devices…" : "no devices — try [scan]"
    }

    ListView {
        id: list
        width: parent.width
        height: Math.min(contentHeight, 6 * 36)
        visible: BluetoothState.powered && count > 0
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: BluetoothState.devices

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property string status: BluetoothState.stateText(modelData)
            width: ListView.view.width
            height: 34
            color: "transparent"

            Marker { visible: row.modelData.connected }

            Icon {
                id: devIcon
                anchors.left: parent.left
                anchors.leftMargin: 10
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

        Rectangle {
            visible: list.interactive
            parent: list
            x: list.width - width
            y: list.visibleArea.yPosition * list.height
            width: 3
            height: list.visibleArea.heightRatio * list.height
            color: Colors.dim
        }
    }
}
