// Battery popup, opened by clicking the battery widget in Bar.qml: icon,
// percentage and state, plus time to empty/full and the current power draw
// when UPower knows them.
import Quickshell.Services.UPower
import QtQuick
import quickshell
import "../state"
import "../components"

BarPopup {
    id: menu
    name: "battery"
    fixedWidth: 0

    readonly property var device: UPower.displayDevice
    readonly property bool charging: device.state === UPowerDeviceState.Charging
    readonly property real pct: device.percentage * 100
    readonly property real seconds: charging ? device.timeToFull : device.timeToEmpty

    function duration(sec) {
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    Row {
        spacing: 8

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 18
            color: menu.pct <= 15 && !menu.charging ? Colors.red : menu.pct <= 30 ? Colors.amber : Colors.neon
            text: BatteryState.icon(menu.pct, menu.charging)
        }

        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
            font.bold: true
            color: Colors.neon
            text: Math.round(menu.pct) + "%"
        }

        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
            text: {
                switch (menu.device.state) {
                    case UPowerDeviceState.Charging: return "charging"
                    case UPowerDeviceState.FullyCharged: return "fully charged"
                    case UPowerDeviceState.Discharging: return "on battery"
                    default: return "state unknown"
                }
            }
        }
    }

    MonoText {
        visible: text !== ""
        color: Colors.gray2
        text: {
            const parts = []
            if (menu.seconds > 0) parts.push(menu.duration(menu.seconds) + (menu.charging ? " to full" : " left"))
            if (Math.abs(menu.device.changeRate) > 0.05) parts.push(Math.abs(menu.device.changeRate).toFixed(1) + " W")
            return parts.join(" · ")
        }
    }
}
