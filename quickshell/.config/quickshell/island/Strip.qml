// The collapsed island: workspaces │ clock │ status, in one row.
//  - workspaces as tmux-style text, the focused one inverted, urgent red
//  - the clock (click: calendar tab)
//  - status (click: system tab): the screen recording while one runs
//    (click stops it), weather, network, battery, and ● while
//    notifications are unread (click: notifications tab). The status
//    carries what needs attention the way the old ≡ icon did: red when
//    offline, on very weak wi-fi or a nearly empty battery; amber when
//    merely weak/low or a tray app wants attention.
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
    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery
    readonly property bool onBattery: hasBattery
        && UPower.displayDevice.state !== UPowerDeviceState.Charging
        && UPower.displayDevice.state !== UPowerDeviceState.FullyCharged
    readonly property bool weakWifi: NetworkState.kind === "wifi" && NetworkState.signal < 50
    readonly property color attention: {
        if (NetworkState.kind === "none" || (weakWifi && NetworkState.signal < 25) || (onBattery && pct <= 15))
            return Colors.red
        if (weakWifi || (onBattery && pct <= 30)
                || SystemTray.items.values.some(i => i.status === Status.NeedsAttention))
            return Colors.amber
        return Colors.gray2
    }
    readonly property string netLabel: {
        const p = NetworkState.primary
        if (!p || !p.connected) return "offline"
        const name = p.type === "wifi" ? p.connection : p.type === "wwan" ? "mobile" : "wired"
        return NetworkState.activeVpns.length ? name + "·vpn" : name
    }

    component Seg: MonoText {
        font.pixelSize: 13
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
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

    // clock
    Seg {
        id: clock
        anchors.centerIn: parent
        font.bold: true
        color: IslandState.tab === "calendar" && IslandState.screen === strip.screen ? Colors.fg : Colors.neon
        text: Qt.formatDateTime(new Date(), "HH:mm")

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm")
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: IslandState.toggle("calendar", strip.screen)
        }
    }

    // status
    Row {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

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

        Item {
            implicitWidth: statusRow.implicitWidth
            implicitHeight: statusRow.implicitHeight
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: statusRow
                spacing: 8

                Row {
                    visible: WeatherState.available
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Icon {
                        text: WeatherState.glyph
                        color: Colors.gray2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Seg { color: Colors.gray2; text: WeatherState.temp }
                }
                Seg { color: strip.attention === Colors.gray2 ? Colors.gray2 : strip.attention; text: strip.netLabel }
                Seg {
                    visible: strip.hasBattery
                    color: strip.onBattery && strip.pct <= 15 ? Colors.red
                        : strip.onBattery && strip.pct <= 30 ? Colors.amber : Colors.gray2
                    text: Math.round(strip.pct) + "%"
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandState.toggle("system", strip.screen)
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
