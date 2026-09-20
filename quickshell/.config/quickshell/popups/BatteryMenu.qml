// Battery popup, opened by clicking the battery widget in Bar.qml. Kept to
// one line — icon, percentage, state — since that's all the widget's icon
// itself can't already show.
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"

PanelWindow {
    id: menu
    visible: BatteryState.menuOpen
    // See NetworkMenu.qml's comment on this — Exclusive instead of the
    // on-demand "focusable: true" so Escape closes this immediately.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // See NetworkMenu.qml's comment on this — keeps the bar clickable
    // underneath while this popup is open.
    margins.top: 28

    readonly property var device: UPower.displayDevice

    onVisibleChanged: {
        if (visible) Qt.callLater(() => catcher.forceActiveFocus())
    }

    MouseArea {
        anchors.fill: parent
        onClicked: BatteryState.menuOpen = false
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: BatteryState.menuOpen = false
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 10
        width: content.implicitWidth + 24
        height: content.implicitHeight + 16
        color: Colors.black
        border.color: Colors.neon
        border.width: 2
        radius: 6

        MouseArea {
            anchors.fill: parent
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 18
                color: {
                    const pct = menu.device.percentage * 100
                    if (pct <= 15 && menu.device.state !== UPowerDeviceState.Charging) return Colors.red
                    if (pct <= 30) return Colors.amber
                    return Colors.neon
                }
                text: BatteryState.icon(menu.device.percentage * 100, menu.device.state === UPowerDeviceState.Charging)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: "monospace"
                font.pixelSize: 13
                font.bold: true
                color: Colors.neon
                text: Math.round(menu.device.percentage * 100) + "%"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: "monospace"
                font.pixelSize: 13
                color: Colors.fg
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
}
