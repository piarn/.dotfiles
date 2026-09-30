// The island's system tab (quick settings): opened from the island's status
// segments or $mod+n. Parts:
//  - tray: the StatusNotifierItem icons apps register (Slack, nm-applet, …)
//    — the bar has no tray of its own, like Windows' hidden-icons flyout.
//    Left click activates (menu-only items open their menu), right click
//    opens the menu, middle click is the secondary action, wheel scrolls.
//  - toggles: network (what traffic goes over, VPNs included; click for
//    the network popup), bluetooth, keep awake, night
//    light, power profile; the › on a tile opens that feature's full popup
//    (bluetooth's is a section of the network popup)
//  - volume/mic/brightness sliders (middle click mutes, wheel steps); the
//    chevron before volume/mic lists the output/input devices to pick from
//  - media controls for the MPRIS player that's playing (or was last)
//  - battery (with time left and power draw), lock and power
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import quickshell
import "../../state"
import "../../components"
import ".."

Tab {
    id: menu
    name: "system"

    property string hoveredTitle: ""
    property string devicesShown: ""   // "" | "output" | "input"
    // Ruled grid: spacing -1 overlaps neighbouring tiles' rules into one.
    readonly property int tileWidth: (innerWidth + 1) / 2

    onOpened: {
        devicesShown = ""
        BrightnessState.refresh()
    }

    function toggleDevices(kind) {
        devicesShown = devicesShown === kind ? "" : kind
    }

    readonly property var activeVpns: NetworkState.activeVpns

    readonly property var primaryNet: NetworkState.primary

    // Playing player first, else whichever is paused with a track loaded.
    readonly property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying) || players.find(p => p.trackTitle) || null
    }

    function profileName(p) {
        if (p === PowerProfile.PowerSaver) return "power saver"
        if (p === PowerProfile.Performance) return "performance"
        return "balanced"
    }

    function cycleProfile() {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced]
        if (PowerProfiles.hasPerformanceProfile) order.push(PowerProfile.Performance)
        const i = order.indexOf(PowerProfiles.profile)
        PowerProfiles.profile = order[(i + 1) % order.length]
    }

    // tray
    Item {
        width: parent.width
        height: trayLabel.implicitHeight

        MonoText {
            id: trayLabel
            anchors.left: parent.left
            color: Colors.gray
            text: "tray"
        }
        MonoText {
            anchors.right: parent.right
            width: parent.width - trayLabel.implicitWidth - 12
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            color: Colors.gray2
            text: menu.hoveredTitle
        }
    }

    MonoText {
        visible: trayRepeater.count === 0
        color: Colors.gray
        text: "no tray apps running"
    }

    Flow {
        width: parent.width
        spacing: -1
        visible: trayRepeater.count > 0

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            delegate: Rectangle {
                id: trayItem
                required property var modelData
                width: 34
                height: 34
                radius: Style.radius
                color: trayMouse.containsMouse ? Colors.surface : Colors.black
                border.width: Style.border
                border.color: modelData.status === Status.NeedsAttention ? Colors.amber : Colors.dim

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 20
                    source: trayItem.modelData.icon
                    opacity: trayItem.modelData.status === Status.Passive ? 0.5 : 1
                }

                function openMenu() {
                    const p = trayItem.mapToItem(null, 0, trayItem.height + 4)
                    trayItem.modelData.display(menu, p.x, p.y)
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onContainsMouseChanged: menu.hoveredTitle = containsMouse
                        ? (trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id) : ""
                    onClicked: (mouse) => {
                        const item = trayItem.modelData
                        if (mouse.button === Qt.RightButton) {
                            if (item.hasMenu) trayItem.openMenu()
                        } else if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate()
                        } else if (item.onlyMenu && item.hasMenu) {
                            trayItem.openMenu()
                        } else {
                            item.activate()
                            menu.close()
                        }
                    }
                    onWheel: (wheel) => trayItem.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }

    Divider {}

    // toggles
    Grid {
        columns: 2
        spacing: -1

        // What traffic actually goes over; highlighted while a VPN is up.
        // Wi-Fi on/off is in the network popup's header.
        ToggleTile {
            width: menu.tileWidth
            icon: menu.activeVpns.length ? "\u{e62f}" : NetworkState.icon(menu.primaryNet)   // vpn_lock
            title: !menu.primaryNet || !menu.primaryNet.connected ? "Offline"
                : menu.primaryNet.type === "wifi" ? menu.primaryNet.connection
                : menu.primaryNet.type === "wwan" ? "Mobile" : "Ethernet"
            subtitle: {
                const p = menu.primaryNet
                const link = !p || !p.connected ? (NetworkState.wifiEnabled ? "not connected" : "wi-fi off")
                    : p.type === "wifi" ? "wi-fi " + p.signal + "%" : p.type === "wwan" ? "mobile" : "wired"
                return [link].concat(menu.activeVpns).join(" · ")
            }
            active: menu.activeVpns.length > 0
            hasDetail: true
            onToggled: menu.openPopup("network")
            onDetail: menu.openPopup("network")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: BluetoothState.powered ? (BluetoothState.connectedDevices.length ? "\u{e1a8}" : "\u{e1a7}") : "\u{e1a9}"
            title: "Bluetooth"
            subtitle: !BluetoothState.available ? "no adapter"
                : !BluetoothState.powered ? "off"
                : BluetoothState.connectedDevices.length ? BluetoothState.connectedDevices.map(d => d.name).join(", ")
                : "on"
            active: BluetoothState.powered
            hasDetail: true
            onToggled: BluetoothState.togglePower()
            onDetail: menu.openPopup("network")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{efef}"   // coffee (keep awake)
            title: "Keep awake"
            subtitle: IdleState.inhibit ? "no idle lock" : "off"
            active: IdleState.inhibit
            onToggled: IdleState.inhibit = !IdleState.inhibit
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{f03d}"   // nightlight
            title: "Night light"
            subtitle: !NightLightState.available ? "install wlsunset"
                : NightLightState.active ? NightLightState.temperature + "K" : "off"
            active: NightLightState.active
            onToggled: if (NightLightState.available) NightLightState.active = !NightLightState.active
        }

        ToggleTile {
            width: menu.tileWidth
            icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "\u{efde}"   // battery_saver
                : PowerProfiles.profile === PowerProfile.Performance ? "\u{e9e4}" : "\u{eaf6}"   // speed / balance
            title: "Power mode"
            subtitle: menu.profileName(PowerProfiles.profile)
            active: PowerProfiles.profile !== PowerProfile.Balanced
            onToggled: menu.cycleProfile()
        }
    }

    Divider {}

    // sliders — speaker and mic live here instead of on the bar
    LevelRow {
        icon: VolumeState.speakerIcon()
        value: VolumeState.sinkAudio ? VolumeState.sinkAudio.volume : 0
        muted: VolumeState.sinkAudio ? VolumeState.sinkAudio.muted : false
        onMoved: (v) => VolumeState.setVolume(false, v)
        onStepped: (d) => VolumeState.adjustVolume(d)
        onToggled: VolumeState.toggleMute(VolumeState.sinkAudio)
        expandable: true
        expanded: menu.devicesShown === "output"
        onExpandClicked: menu.toggleDevices("output")
    }

    AudioDeviceList {
        visible: menu.devicesShown === "output"
    }

    LevelRow {
        visible: VolumeState.sourceAudio !== null
        icon: VolumeState.micIcon()
        value: VolumeState.sourceAudio ? VolumeState.sourceAudio.volume : 0
        muted: VolumeState.sourceAudio ? VolumeState.sourceAudio.muted : false
        onMoved: (v) => VolumeState.setVolume(true, v)
        onStepped: (d) => VolumeState.adjustMicVolume(d)
        onToggled: VolumeState.toggleMute(VolumeState.sourceAudio)
        expandable: true
        expanded: menu.devicesShown === "input"
        onExpandClicked: menu.toggleDevices("input")
    }

    AudioDeviceList {
        visible: menu.devicesShown === "input"
        input: true
    }

    LevelRow {
        visible: BrightnessState.available
        icon: "\u{e1ac}"   // brightness_high
        value: BrightnessState.value
        onMoved: (v) => BrightnessState.set(v)
        onStepped: (d) => BrightnessState.set(BrightnessState.value + d)
    }

    // media
    Item {
        visible: menu.player !== null
        width: parent.width
        height: visible ? 34 : 0

        Column {
            anchors.left: parent.left
            anchors.right: mediaButtons.left
            anchors.leftMargin: 4
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            MonoText {
                width: parent.width
                elide: Text.ElideRight
                color: Colors.fg
                text: menu.player ? menu.player.trackTitle || menu.player.identity : ""
            }
            MonoText {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                font.pixelSize: 11
                color: Colors.gray2
                text: menu.player ? [menu.player.trackArtist, menu.player.identity]
                    .filter(s => s && s !== menu.player.trackTitle).join(" · ") : ""
            }
        }

        Row {
            id: mediaButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: [
                    { glyph: "\u{e045}", enabled: menu.player && menu.player.canGoPrevious, act: () => menu.player.previous() },   // skip_previous
                    { glyph: menu.player && menu.player.isPlaying ? "\u{e034}" : "\u{e037}",   // pause / play_arrow
                      enabled: menu.player && menu.player.canTogglePlaying, act: () => menu.player.togglePlaying() },
                    { glyph: "\u{e044}", enabled: menu.player && menu.player.canGoNext, act: () => menu.player.next() },   // skip_next
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: 30
                    height: 30
                    radius: Style.radius
                    color: mediaMouse.containsMouse && modelData.enabled ? Colors.surface : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        font.pixelSize: 18
                        color: parent.modelData.enabled ? Colors.acid : Colors.gray
                        text: parent.modelData.glyph
                    }
                    MouseArea {
                        id: mediaMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.modelData.act()
                    }
                }
            }
        }
    }

    Divider {}

    // footer
    Item {
        width: parent.width
        height: lockBtn.implicitHeight

        Row {
            id: batteryRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: UPower.displayDevice.isLaptopBattery

            readonly property var dev: UPower.displayDevice
            readonly property bool charging: dev.state === UPowerDeviceState.Charging

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.gray2
                text: BatteryState.icon(parent.dev.percentage * 100, parent.charging)
            }
            MonoText {
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.gray2
                text: {
                    const d = parent.dev
                    const parts = [Math.round(d.percentage * 100) + "%"]
                    if (parent.charging) parts.push("charging")
                    else if (d.state === UPowerDeviceState.FullyCharged) parts.push("full")
                    const secs = parent.charging ? d.timeToFull : d.timeToEmpty
                    if (secs > 0) {
                        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60)
                        parts.push((h > 0 ? h + "h " + m + "m" : m + "m") + (parent.charging ? " to full" : " left"))
                    }
                    if (Math.abs(d.changeRate) > 0.05) parts.push(Math.abs(d.changeRate).toFixed(1) + " W")
                    return parts.join(" · ")
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 12

            TextButton {
                id: lockBtn
                label: "lock"
                onClicked: {
                    menu.close()
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/dots-lock"])
                }
            }
            TextButton {
                label: "power"
                baseColor: Colors.red
                onClicked: IslandState.openRun(":")
            }
        }
    }
}
