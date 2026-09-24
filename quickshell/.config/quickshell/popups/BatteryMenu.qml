// Battery popup, opened by clicking the battery widget in Bar.qml. Kept to
// one line — icon, percentage, state — since that's all the widget's icon
// itself can't already show.
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
}
