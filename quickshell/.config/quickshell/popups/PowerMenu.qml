// Power menu runner, toggled by sway's Mod+Shift+Escape (Mod+Escape alone
// is the direct-to-lock shortcut — this is the deliberate "one step further"
// version with a moment to pick). Same shape as Launcher.qml: a centered
// CardWindow, arrow-key/mouse selection, Enter to run.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import quickshell
import "../components"

CardWindow {
    id: powerMenu
    visible: false
    centered: true
    needsKeyboard: true
    cardWidth: content.implicitWidth + 32
    cardHeight: content.implicitHeight + 24
    initialFocus: keys
    WlrLayershell.namespace: "quickshell-powermenu"
    onDismissed: powerMenu.visible = false

    readonly property var actions: [
        { label: "lock", icon: "\u{f023}", run: () => Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"]) },
        { label: "suspend", icon: "\u{f04b2}", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { label: "reboot", icon: "\u{f0709}", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { label: "shutdown", icon: "\u{f011}", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
        { label: "logout", icon: "\u{f0343}", run: () => Quickshell.execDetached(["swaymsg", "exit"]) },
    ]
    property int selected: 0

    function run(action) {
        powerMenu.visible = false
        action.run()
    }

    onVisibleChanged: if (visible) selected = 0

    IpcHandler {
        target: "powermenu"
        function toggle(): void { powerMenu.visible = !powerMenu.visible }
        function close(): void { powerMenu.visible = false }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: powerMenu.visible = false
        Keys.onReturnPressed: powerMenu.run(powerMenu.actions[powerMenu.selected])
        Keys.onLeftPressed: powerMenu.selected = Math.max(0, powerMenu.selected - 1)
        Keys.onRightPressed: powerMenu.selected = Math.min(powerMenu.actions.length - 1, powerMenu.selected + 1)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: powerMenu.actions

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: 84
                height: 72
                radius: 6
                color: index === powerMenu.selected ? Colors.dim : "transparent"
                border.color: index === powerMenu.selected ? Colors.neon : "transparent"
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 26
                        color: index === powerMenu.selected ? Colors.neon : Colors.fg
                        text: modelData.icon
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: "monospace"
                        font.pixelSize: 12
                        color: index === powerMenu.selected ? Colors.neon : Colors.gray
                        text: modelData.label
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: powerMenu.selected = index
                    onClicked: powerMenu.run(modelData)
                }
            }
        }
    }
}
