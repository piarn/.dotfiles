// Status bar, replacing waybar. One PanelWindow per screen (Variants), with
// sway workspaces on the left, a clock centered, and network/battery on the
// right — same layout waybar had (see ~/.dots/waybar's old config.jsonc in
// git history). Colors from the rice theme via the Colors singleton.
import Quickshell
import Quickshell.I3
import Quickshell.Services.UPower
import QtQuick
import quickshell
import "./state"

Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: bar
        required property var modelData
        screen: modelData
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 32
        color: "transparent"

        // The bar itself is transparent full-width — only these three
        // pills (workspaces, clock, widgets) paint a background, so the
        // wallpaper shows through everywhere else along the strip.
        readonly property int pillHeight: 24

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            color: Colors.black
            radius: 6
            width: left.implicitWidth + 12
            height: bar.pillHeight

            Row {
                id: left
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: I3.workspaces

                    delegate: Rectangle {
                        required property var modelData
                        width: label.implicitWidth + 16
                        height: bar.pillHeight
                        radius: 6
                        color: modelData.focused ? Colors.neon
                            : modelData.urgent ? Colors.red
                            : "transparent"

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.name
                            font.family: "monospace"
                            font.pixelSize: 13
                            color: modelData.focused || modelData.urgent ? Colors.black : Colors.gray
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            color: Colors.black
            radius: 6
            width: clock.implicitWidth + 20
            height: bar.pillHeight

            Text {
                id: clock
                anchors.centerIn: parent
                font.family: "monospace"
                font.pixelSize: 13
                font.bold: true
                color: Colors.neon
                text: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clock.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6
            color: Colors.black
            radius: 6
            width: widgets.implicitWidth + 20
            height: bar.pillHeight

            Row {
                id: widgets
                anchors.centerIn: parent
                spacing: 16

                Item {
                    id: network
                    anchors.verticalCenter: parent.verticalCenter
                    width: netLabel.implicitWidth
                    height: netLabel.implicitHeight

                    // Live status is polled once in the NetworkState singleton (not
                    // here — this Item used to poll nmcli itself, which meant one
                    // poller *per screen* under Variants) and shared with the
                    // NetworkMenu.qml popup this opens on click. Signal strength
                    // itself only shows in that popup now — this is icon-only.
                    function wifiIcon(pct) {
                        if (pct >= 75) return "\u{f0928}"
                        if (pct >= 50) return "\u{f0925}"
                        if (pct >= 25) return "\u{f0922}"
                        return "\u{f091f}"
                    }

                    Text {
                        id: netLabel
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                        color: {
                            if (NetworkState.kind === "wifi") {
                                if (NetworkState.signal < 25) return Colors.red
                                if (NetworkState.signal < 50) return Colors.amber
                                return Colors.acid
                            }
                            if (NetworkState.kind === "eth") return Colors.acid
                            return Colors.red
                        }
                        text: {
                            if (NetworkState.kind === "wifi") return network.wifiIcon(NetworkState.signal)
                            if (NetworkState.kind === "eth") return "\u{f0200}"
                            return "\u{f092d}"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: tooltip.visible = true
                        onExited: tooltip.visible = false
                        onClicked: PopupState.toggle("network")
                    }

                    Rectangle {
                        id: tooltip
                        visible: false
                        color: Colors.black
                        border.color: Colors.dim
                        border.width: 1
                        radius: 4
                        width: tooltipLabel.implicitWidth + 16
                        height: tooltipLabel.implicitHeight + 12
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        anchors.right: parent.right

                        Text {
                            id: tooltipLabel
                            anchors.centerIn: parent
                            font.family: "monospace"
                            font.pixelSize: 12
                            color: Colors.fg
                            text: {
                                if (NetworkState.kind === "wifi")
                                    return "SSID: " + NetworkState.ssid + " (" + NetworkState.signal + "%)" + "\nDevice: " + NetworkState.device + "\nIP: " + (NetworkState.ip || "—") + "\n(click for networks)"
                                if (NetworkState.kind === "eth")
                                    return "Device: " + NetworkState.device + "\nIP: " + (NetworkState.ip || "—") + "\n(click for networks)"
                                return "No active connection\n(click for networks)"
                            }
                        }
                    }
                }

                Item {
                    id: bluetooth
                    anchors.verticalCenter: parent.verticalCenter
                    width: bluetoothRow.implicitWidth
                    height: bluetoothRow.implicitHeight

                    Row {
                        id: bluetoothRow
                        spacing: 4

                        // Nerd Font glyphs (md-bluetooth / md-bluetooth_off) —
                        // needs ~/.local/share/fonts/NerdFontSymbols installed
                        // (see ~/.rice/README.md's quickshell entry);
                        // "monospace" alone has no bluetooth icon of any kind,
                        // patched or otherwise.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 15
                            color: BluetoothState.powered ? Colors.neon : Colors.red
                            text: BluetoothState.powered ? "\u{f00af}" : "\u{f00b2}"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "monospace"
                            font.pixelSize: 13
                            color: Colors.fg
                            visible: text !== ""
                            text: {
                                const connected = BluetoothState.devices.filter(d => d.connected)
                                return connected.length > 0 ? connected[0].name : ""
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: PopupState.toggle("bluetooth")
                    }
                }

                Item {
                    id: volume
                    anchors.verticalCenter: parent.verticalCenter
                    width: volumeIcon.implicitWidth
                    height: volumeIcon.implicitHeight

                    Text {
                        id: volumeIcon
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                        color: VolumeState.sinkAudio && VolumeState.sinkAudio.muted ? Colors.red : Colors.acid
                        text: VolumeState.speakerIcon()
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                if (VolumeState.sinkAudio) VolumeState.sinkAudio.muted = !VolumeState.sinkAudio.muted
                            } else {
                                PopupState.toggle("volume")
                            }
                        }
                        onWheel: (wheel) => VolumeState.adjustVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                    }
                }

                Item {
                    id: mic
                    anchors.verticalCenter: parent.verticalCenter
                    width: micIcon.implicitWidth
                    height: micIcon.implicitHeight

                    Text {
                        id: micIcon
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                        color: VolumeState.sourceAudio && VolumeState.sourceAudio.muted ? Colors.red : Colors.acid
                        text: VolumeState.micIcon()
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                if (VolumeState.sourceAudio) VolumeState.sourceAudio.muted = !VolumeState.sourceAudio.muted
                            } else {
                                PopupState.toggle("mic")
                            }
                        }
                        onWheel: (wheel) => VolumeState.adjustMicVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                    }
                }

                Item {
                    id: battery
                    anchors.verticalCenter: parent.verticalCenter
                    width: batteryIcon.implicitWidth
                    height: batteryIcon.implicitHeight
                    visible: UPower.displayDevice.isLaptopBattery

                    // Percentage/state/time-remaining moved to BatteryMenu.qml
                    // (click to open) — this is icon-only, tiered by charge
                    // level and charging state (see BatteryState.icon()).
                    Text {
                        id: batteryIcon
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                        color: {
                            const pct = UPower.displayDevice.percentage * 100
                            const charging = UPower.displayDevice.state === UPowerDeviceState.Charging
                            if (pct <= 15 && !charging) return Colors.red
                            if (pct <= 30) return Colors.amber
                            return Colors.acid
                        }
                        text: BatteryState.icon(
                            UPower.displayDevice.percentage * 100,
                            UPower.displayDevice.state === UPowerDeviceState.Charging
                        )
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: PopupState.toggle("battery")
                    }
                }
            }
        }
    }
}
