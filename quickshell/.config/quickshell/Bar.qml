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

                    // No hover tooltip here — a plain child Rectangle
                    // anchored below the icon gets clipped by the bar's own
                    // 32px-tall surface (Wayland layer-shell surfaces can't
                    // draw outside their own bounds), so it never showed
                    // more than a 1px sliver of its border. The same detail
                    // (SSID/signal/IP) is one click away in NetworkMenu.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: PopupState.toggle("network")
                    }
                }

                Item {
                    id: bluetooth
                    anchors.verticalCenter: parent.verticalCenter
                    width: bluetoothRow.implicitWidth
                    height: bluetoothRow.implicitHeight

                    readonly property var connectedDevices: BluetoothState.devices.filter(d => d.connected)

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
                            color: BluetoothState.powered ? Colors.acid : Colors.red
                            text: BluetoothState.powered ? "\u{f00af}" : "\u{f00b2}"
                        }

                        // A connected/disconnected indicator (filled/hollow
                        // dot) rather than the device's name — the name is
                        // still one hover away via the tooltip, or a click
                        // away in the full popup. Hidden entirely when
                        // bluetooth itself is off, since the main icon
                        // already turns red for that. Plain Unicode dots
                        // instead of nerd font glyphs (e.g. check/xmark) —
                        // those render at noticeably different visual
                        // weights from each other at the same pixelSize.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: Colors.acid
                            visible: BluetoothState.powered
                            text: bluetooth.connectedDevices.length > 0 ? "●" : "○"
                        }
                    }

                    // No hover tooltip here — see NetworkMenu's identical
                    // fix above: a plain child Rectangle below the icon gets
                    // clipped by the bar's own 32px-tall surface, so it
                    // never showed more than a sliver of its border. Device
                    // names are one click away in BluetoothMenu.
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

                // Same icon+dot shape as bluetooth above: bell color carries
                // mute state (red when muted, matching bluetooth's
                // powered-off red), the dot carries "is there anything to
                // see" (solid/hollow, matching bluetooth's connected dot).
                // Mute toggle lives inside the popup itself, not here.
                Item {
                    id: notifications
                    anchors.verticalCenter: parent.verticalCenter
                    width: notifRow.implicitWidth
                    height: notifRow.implicitHeight

                    Row {
                        id: notifRow
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 15
                            color: NotificationState.muted ? Colors.red : Colors.acid
                            text: NotificationState.muted ? "\u{f1f6}" : "\u{f0f3}"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: Colors.acid
                            text: NotificationState.notifications.length > 0 ? "●" : "○"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: PopupState.toggle("notifications")
                    }
                }
            }
        }
    }
}
