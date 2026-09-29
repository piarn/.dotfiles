// Status bar, replacing waybar. One PanelWindow per screen (Variants), with
// sway workspaces on the left (styled like tmux's window list), a clock
// centered, and a single ≡ quick settings button on the right (plus a recording indicator while
// screenrec runs). Popups open on this bar's own screen. Colors from the rice theme via the Colors
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
            radius: Style.radius
            border.width: Style.border
            border.color: Colors.dim
            width: left.implicitWidth + 2 * Style.border
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
                        height: bar.pillHeight - 2 * Style.border
                        color: modelData.focused ? Colors.neon
                            : modelData.urgent ? Colors.red
                            : "transparent"

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.name
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: modelData.focused
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
            radius: Style.radius
            border.width: Style.border
            border.color: Colors.dim
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
            radius: Style.radius
            border.width: Style.border
            border.color: Colors.dim
            width: widgets.implicitWidth + 20
            height: bar.pillHeight

            Row {
                id: widgets
                anchors.centerIn: parent
                spacing: 16

                // Only while ~/.local/bin/screenrec records; click to stop.
                Item {
                    visible: RecorderState.recording
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: recRow.implicitWidth
                    implicitHeight: recRow.implicitHeight

                    Row {
                        id: recRow
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: Colors.red
                            text: "●"
                            SequentialAnimation on opacity {
                                running: RecorderState.recording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 700 }
                                NumberAnimation { to: 1; duration: 700 }
                            }
                        }
                        MonoText {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Colors.red
                            text: RecorderState.elapsedText()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: RecorderState.stop()
                    }
                }

                // Focus timer from the hub while it runs; click to stop.
                Item {
                    visible: FocusState.running
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: focusRow.implicitWidth
                    implicitHeight: focusRow.implicitHeight

                    Row {
                        id: focusRow
                        spacing: 5

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 13
                            color: Colors.neon
                            text: "\u{f051f}"
                        }
                        MonoText {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Colors.neon
                            text: FocusState.text()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: FocusState.stop()
                    }
                }

                // The only widget: quick settings, which holds everything else
                // (network, bluetooth, notifications, battery, tray; each tile's
                // › opens that feature's full popup). The icon only carries what
                // needs attention: red when offline, on very weak wi-fi or a
                // nearly empty battery; amber when merely weak/low or a tray app
                // wants attention; a dot while there are unread notifications.
                BarWidget {
                    readonly property real pct: UPower.displayDevice.percentage * 100
                    readonly property bool onBattery: UPower.displayDevice.isLaptopBattery
                        && UPower.displayDevice.state !== UPowerDeviceState.Charging
                        && UPower.displayDevice.state !== UPowerDeviceState.FullyCharged
                    readonly property bool weakWifi: NetworkState.kind === "wifi" && NetworkState.signal < 50
                    screen: bar.modelData
                    popup: "quicksettings"
                    icon: "\u{f035c}"
                    iconColor: {
                        if (NetworkState.kind === "none"
                                || (weakWifi && NetworkState.signal < 25)
                                || (onBattery && pct <= 15))
                            return Colors.red
                        if (weakWifi || (onBattery && pct <= 30)
                                || SystemTray.items.values.some(i => i.status === Status.NeedsAttention))
                            return Colors.amber
                        return Colors.acid
                    }
                    showDot: NotificationState.notifications.length > 0
                    dotFilled: true
                }
            }
        }
    }
}
