// The collapsed island: only what's needed at a glance.
//  - left: workspaces as tmux-style text, the focused one inverted, urgent red
//  - center: date and time, yyyy-MM-dd HH:mm:ss (click: calendar tab)
//  - right: nothing, unless something wants attention —
//      offline (red) / weak wi-fi (amber), battery % at 30% or below on
//      battery (amber, red at 15%), "tray" when a tray app asks for
//      attention, the screen recording while one runs (click stops it),
//      and ● while notifications are unread (click: notifications tab)
// Everything else (network name, VPN, full battery, weather) lives in the
// tabs. Clicking anywhere else on the strip opens the system tab.
import Quickshell
import Quickshell.I3
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import QtQuick
import quickshell
import "../state"
import "../components"

Item {
    id: strip

    required property var screen
    implicitHeight: 28

    readonly property real pct: UPower.displayDevice.percentage * 100
    readonly property bool onBattery: UPower.displayDevice.isLaptopBattery
        && UPower.displayDevice.state !== UPowerDeviceState.Charging
        && UPower.displayDevice.state !== UPowerDeviceState.FullyCharged
    readonly property bool offline: NetworkState.kind === "none"
    readonly property bool weakWifi: NetworkState.kind === "wifi" && NetworkState.signal < 50
    readonly property bool lowBattery: onBattery && pct <= 30
    readonly property bool trayAttention: SystemTray.items.values.some(i => i.status === Status.NeedsAttention)

    component Seg: MonoText {
        font.pixelSize: 13
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    // the strip's empty space: system tab
    MouseArea {
        anchors.fill: parent
        onClicked: IslandState.toggle("system", strip.screen)
    }

    // workspaces
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: I3.workspaces

            delegate: Rectangle {
                required property var modelData
                width: label.implicitWidth + 12
                height: 20
                color: modelData.focused ? Colors.neon : modelData.urgent ? Colors.red : "transparent"

                MonoText {
                    id: label
                    anchors.centerIn: parent
                    font.pixelSize: 13
                    font.bold: modelData.focused
                    color: modelData.focused || modelData.urgent ? Colors.black : Colors.gray
                    text: modelData.name
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        IslandState.close()
                        modelData.activate()
                    }
                }
            }
        }
    }

    // date and time
    Seg {
        id: clock
        anchors.centerIn: parent
        font.bold: true
        color: IslandState.tab === "calendar" && IslandState.screen === strip.screen ? Colors.fg : Colors.neon
        text: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: IslandState.toggle("calendar", strip.screen)
        }
    }

    // alerts only
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Seg {
            visible: strip.offline || strip.weakWifi
            color: strip.offline || NetworkState.signal < 25 ? Colors.red : Colors.amber
            text: strip.offline ? "offline" : "weak wi-fi"
        }
        Seg {
            visible: strip.lowBattery
            color: strip.pct <= 15 ? Colors.red : Colors.amber
            text: Math.round(strip.pct) + "%"
        }
        Seg {
            visible: strip.trayAttention
            color: Colors.amber
            text: "tray"
        }

        // only while ~/.local/bin/screenrec records; click to stop
        Item {
            visible: RecorderState.recording
            implicitWidth: recRow.implicitWidth
            implicitHeight: recRow.implicitHeight
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: recRow
                spacing: 4

                Seg {
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
                Seg { color: Colors.red; text: RecorderState.elapsedText() }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: RecorderState.stop()
            }
        }

        // unread notifications
        Seg {
            visible: NotificationState.notifications.length > 0
            font.pixelSize: 11
            color: Colors.acid
            text: "●"

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandState.toggle("notifications", strip.screen)
            }
        }
    }
}
