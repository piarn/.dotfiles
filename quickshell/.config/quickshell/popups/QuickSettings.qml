// Quick settings, opened from the ≡ at the end of the bar. Three parts:
//  - tray: the StatusNotifierItem icons apps register (Slack, nm-applet, …)
//    — the bar has no tray of its own, like Windows' hidden-icons flyout.
//    Left click activates (menu-only items open their menu), right click
//    opens the menu, middle click is the secondary action, wheel scrolls.
//  - toggles: wi-fi, bluetooth, do not disturb, keep awake, power profile;
//    the › on a tile opens that feature's full popup
//  - volume/mic/brightness sliders (middle click mutes, wheel steps); the
//    chevron before volume/mic lists the output/input devices to pick from
//  - battery, lock and power
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import quickshell
import "../state"
import "../components"

BarPopup {
    id: menu
    name: "quicksettings"
    fixedWidth: 360

    property string hoveredTitle: ""
    property string devicesShown: ""   // "" | "output" | "input"
    readonly property int tileWidth: (innerWidth - 8) / 2

    onOpened: {
        devicesShown = ""
        BrightnessState.refresh()
    }

    function toggleDevices(kind) {
        devicesShown = devicesShown === kind ? "" : kind
    }

    function openPopup(popupName) {
        PopupState.toggle(popupName, menu.screen)
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
        spacing: 4
        visible: trayRepeater.count > 0

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            delegate: Rectangle {
                id: trayItem
                required property var modelData
                width: 34
                height: 34
                radius: 6
                color: trayMouse.containsMouse ? Colors.dim : Colors.surface
                border.width: modelData.status === Status.NeedsAttention ? 1 : 0
                border.color: Colors.amber

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
        spacing: 8

        ToggleTile {
            width: menu.tileWidth
            icon: NetworkState.wifiEnabled ? "\u{f05a9}" : "\u{f05aa}"
            title: "Wi-Fi"
            subtitle: !NetworkState.wifiEnabled ? "off"
                : NetworkState.wifiDevice && NetworkState.wifiDevice.connected ? NetworkState.wifiDevice.connection
                : "not connected"
            active: NetworkState.wifiEnabled
            hasDetail: true
            onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
            onDetail: menu.openPopup("network")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: BluetoothState.powered ? (BluetoothState.connectedDevices.length ? "\u{f00b1}" : "\u{f00af}") : "\u{f00b2}"
            title: "Bluetooth"
            subtitle: !BluetoothState.available ? "no adapter"
                : !BluetoothState.powered ? "off"
                : BluetoothState.connectedDevices.length ? BluetoothState.connectedDevices.map(d => d.name).join(", ")
                : "on"
            active: BluetoothState.powered
            hasDetail: true
            onToggled: BluetoothState.togglePower()
            onDetail: menu.openPopup("bluetooth")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: NotificationState.dnd ? "\u{f009b}" : "\u{f009a}"
            title: "Silence"
            subtitle: NotificationState.dnd ? "toasts hidden" : "off"
            active: NotificationState.dnd
            hasDetail: true
            onToggled: NotificationState.toggleDnd()
            onDetail: menu.openPopup("notifications")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{f0176}"
            title: "Keep awake"
            subtitle: IdleState.inhibit ? "no idle lock" : "off"
            active: IdleState.inhibit
            onToggled: IdleState.inhibit = !IdleState.inhibit
        }

        ToggleTile {
            width: menu.tileWidth
            icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "\u{f032a}"
                : PowerProfiles.profile === PowerProfile.Performance ? "\u{f04c5}" : "\u{f05d1}"
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
        icon: "\u{f00e0}"
        value: BrightnessState.value
        onMoved: (v) => BrightnessState.set(v)
        onStepped: (d) => BrightnessState.set(BrightnessState.value + d)
    }

    Divider {}

    // footer
    Item {
        width: parent.width
        height: lockBtn.implicitHeight

        Row {
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
                text: Math.round(parent.dev.percentage * 100) + "%"
                    + (parent.charging ? " · charging" : parent.dev.state === UPowerDeviceState.FullyCharged ? " · full" : "")
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
                    Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"])
                }
            }
            TextButton {
                label: "power"
                baseColor: Colors.red
                onClicked: {
                    menu.close()
                    Quickshell.execDetached(["qs", "ipc", "call", "powermenu", "toggle"])
                }
            }
        }
    }
}
