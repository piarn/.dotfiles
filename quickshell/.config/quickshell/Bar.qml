// Status bar, replacing waybar. One PanelWindow per screen (Variants), with
// sway workspaces on the left, a clock centered, and status widgets on the
// right ending in the ≡ tray/quick-settings button. Each widget opens its
// popup on this bar's own screen. Colors from the rice theme via the Colors
// singleton.
import Quickshell
import Quickshell.I3
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import quickshell
import "./state"
import "./components"

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

        // Clicking empty bar space (or the clock) closes an open popup;
        // widgets and workspace buttons sit above this and get their own
        // clicks first.
        MouseArea {
            anchors.fill: parent
            enabled: PopupState.current !== ""
            onClicked: PopupState.close()
        }

        // Quick settings' "keep awake": the bar is always mapped, which is
        // what the idle-inhibit protocol needs from the inhibiting surface.
        IdleInhibitor {
            window: bar
            enabled: IdleState.inhibit
        }

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
                            onClicked: {
                                PopupState.close()
                                modelData.activate()
                            }
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

                // Icon follows the *primary* device (lowest-metric default
                // route), i.e. where traffic actually goes; every interface is
                // listed in NetworkMenu. VPN glyph appended while one is up.
                BarWidget {
                    screen: bar.modelData
                    popup: "network"
                    icon: NetworkState.icon(NetworkState.primary) + (NetworkState.vpnActive ? " \u{f0582}" : "")
                    iconColor: {
                        if (NetworkState.kind === "wifi") {
                            if (NetworkState.signal < 25) return Colors.red
                            if (NetworkState.signal < 50) return Colors.amber
                            return Colors.acid
                        }
                        return NetworkState.kind === "eth" ? Colors.acid : Colors.red
                    }
                }

                // Dot: something connected. Hidden when off, since the icon
                // already turns red for that.
                BarWidget {
                    screen: bar.modelData
                    popup: "bluetooth"
                    icon: BluetoothState.powered ? "\u{f00af}" : "\u{f00b2}"
                    iconColor: BluetoothState.powered ? Colors.acid : Colors.red
                    showDot: BluetoothState.powered
                    dotFilled: BluetoothState.connectedDevices.length > 0
                }

                BarWidget {
                    readonly property real pct: UPower.displayDevice.percentage * 100
                    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
                    visible: UPower.displayDevice.isLaptopBattery
                    screen: bar.modelData
                    popup: "battery"
                    icon: BatteryState.icon(pct, charging)
                    iconColor: pct <= 15 && !charging ? Colors.red : pct <= 30 ? Colors.amber : Colors.acid
                }

                // Bell color carries do-not-disturb, the dot "anything to read".
                BarWidget {
                    screen: bar.modelData
                    popup: "notifications"
                    icon: NotificationState.dnd ? "\u{f009b}" : "\u{f009a}"
                    iconColor: NotificationState.dnd ? Colors.red : Colors.acid
                    showDot: true
                    dotFilled: NotificationState.notifications.length > 0
                }

                // Tray + quick settings. Amber while a tray app wants attention.
                BarWidget {
                    screen: bar.modelData
                    popup: "quicksettings"
                    icon: "\u{f035c}"
                    iconColor: SystemTray.items.values.some(i => i.status === Status.NeedsAttention) ? Colors.amber : Colors.acid
                }
            }
        }
    }
}
