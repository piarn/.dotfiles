// The collapsed island, one row:
//  - left: workspaces 1–5 always (empty ones dim, click to go there), plus
//    any higher one that exists; focused inverted, urgent red
//  - center: date and time, yy/MM/dd HH:mm:ss (click: calendar tab)
//  - right: quick icons with tooltips — silence, bluetooth, mic, volume,
//    network, battery. Click toggles (wheel on volume/mic steps it), right
//    click opens the tab with the details. They turn amber/red when
//    something needs attention (offline, weak wi-fi, low battery), the
//    battery also shows its % then. Plus "tray" when a tray app asks for
//    attention, the recording while one runs, and ● for unread
//    notifications (click: notifications tab).
// Clicking anywhere else on the strip opens the system tab.
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
            // "1".."5", then any other workspace that exists
            model: {
                const names = ["1", "2", "3", "4", "5"]
                for (const w of I3.workspaces.values)
                    if (names.indexOf(w.name) < 0) names.push(w.name)
                return names
            }

            delegate: Rectangle {
                required property string modelData
                readonly property var ws: I3.workspaces.values.find(w => w.name === modelData) || null
                width: label.implicitWidth + 12
                height: 20
                color: ws && ws.focused ? Colors.neon : ws && ws.urgent ? Colors.red : "transparent"

                MonoText {
                    id: label
                    anchors.centerIn: parent
                    font.pixelSize: 13
                    font.bold: parent.ws !== null && parent.ws.focused
                    color: !parent.ws ? Colors.dim
                        : parent.ws.focused || parent.ws.urgent ? Colors.black : Colors.gray
                    text: modelData
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        IslandState.close()
                        if (parent.ws) parent.ws.activate()
                        else I3.dispatch("workspace number " + parent.modelData)
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
        text: Qt.formatDateTime(new Date(), "yy/MM/dd HH:mm:ss")

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), "yy/MM/dd HH:mm:ss")
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: IslandState.toggle("calendar", strip.screen)
        }
    }

    // quick icons
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

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

        QuickIcon {
            glyph: NotificationState.dnd ? "\u{e7f6}" : "\u{e7f5}"   // notifications_off / notifications
            tint: NotificationState.dnd ? Colors.amber : Colors.gray2
            tip: NotificationState.dnd ? "silenced · critical only" : "notifications on"
            onClicked: NotificationState.toggleDnd()
            onRightClicked: IslandState.open("notifications", strip.screen)
        }

        QuickIcon {
            visible: BluetoothState.available
            glyph: BluetoothState.powered ? (BluetoothState.connectedDevices.length ? "\u{e1a8}" : "\u{e1a7}") : "\u{e1a9}"
            tint: BluetoothState.powered ? Colors.gray2 : Colors.dim
            tip: !BluetoothState.powered ? "bluetooth off"
                : BluetoothState.connectedDevices.length ? "bluetooth · " + BluetoothState.connectedDevices.map(d => d.name).join(", ")
                : "bluetooth on"
            onClicked: BluetoothState.togglePower()
            onRightClicked: IslandState.open("network", strip.screen)
        }

        QuickIcon {
            readonly property var audio: VolumeState.sourceAudio
            glyph: VolumeState.micIcon()
            tint: audio && audio.muted ? Colors.dim : Colors.gray2
            tip: !audio ? "no microphone" : audio.muted ? "mic muted" : "mic " + Math.round(audio.volume * 100) + "%"
            onClicked: VolumeState.toggleMute(audio)
            onRightClicked: IslandState.open("system", strip.screen)
            onWheeled: (steps) => VolumeState.adjustMicVolume(steps / Style.segments)
        }

        QuickIcon {
            readonly property var audio: VolumeState.sinkAudio
            glyph: VolumeState.speakerIcon()
            tint: audio && audio.muted ? Colors.dim : Colors.gray2
            tip: !audio ? "no output" : audio.muted ? "muted" : "volume " + Math.round(audio.volume * 100) + "%"
            onClicked: VolumeState.toggleMute(audio)
            onRightClicked: IslandState.open("system", strip.screen)
            onWheeled: (steps) => VolumeState.adjustVolume(steps / Style.segments)
        }

        QuickIcon {
            readonly property var p: NetworkState.primary
            glyph: NetworkState.icon(p)
            tint: strip.offline || (strip.weakWifi && NetworkState.signal < 25) ? Colors.red
                : strip.weakWifi ? Colors.amber : Colors.gray2
            tip: {
                if (!p || !p.connected) return NetworkState.wifiEnabled ? "offline" : "offline · wi-fi off"
                const link = p.type === "wifi" ? p.connection + " · " + p.signal + "%" : p.type === "wwan" ? "mobile" : "wired"
                return [link].concat(NetworkState.activeVpns.map(v => "vpn " + v)).join(" · ")
            }
            // left click: wi-fi on/off; right click: the network tab
            onClicked: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
            onRightClicked: IslandState.open("network", strip.screen)
        }

        Row {
            visible: UPower.displayDevice.isLaptopBattery
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            QuickIcon {
                readonly property var d: UPower.displayDevice
                readonly property bool charging: d.state === UPowerDeviceState.Charging
                glyph: BatteryState.icon(strip.pct, charging)
                tint: strip.lowBattery ? (strip.pct <= 15 ? Colors.red : Colors.amber) : Colors.gray2
                tip: {
                    const parts = [Math.round(strip.pct) + "%"]
                    if (charging) parts.push("charging")
                    else if (d.state === UPowerDeviceState.FullyCharged) parts.push("full")
                    const secs = charging ? d.timeToFull : d.timeToEmpty
                    if (secs > 0) {
                        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60)
                        parts.push((h > 0 ? h + "h " + m + "m" : m + "m") + (charging ? " to full" : " left"))
                    }
                    return parts.join(" · ")
                }
                onClicked: IslandState.toggle("system", strip.screen)
                onRightClicked: IslandState.open("system", strip.screen)
            }
            Seg {
                visible: strip.lowBattery
                color: strip.pct <= 15 ? Colors.red : Colors.amber
                text: Math.round(strip.pct) + "%"
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
