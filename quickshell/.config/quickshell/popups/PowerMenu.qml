// Power menu runner, toggled by sway's Mod+Shift+Escape (Mod+Escape alone
// is the direct-to-lock shortcut — this is the deliberate "one step further"
// version with a moment to pick). Same shape as Launcher.qml: a fullscreen
// PanelWindow with a centered box, arrow-key/mouse selection, Enter to run.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import quickshell

PanelWindow {
    id: powerMenu
    visible: false
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // Grabs keyboard focus immediately on map — see Launcher.qml's comment;
    // "focusable" alone is on-demand and only gets granted after a click,
    // which defeats a menu meant to be driven from the keyboard that opened it.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

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

    onVisibleChanged: {
        if (visible) {
            selected = 0
            Qt.callLater(() => catcher.forceActiveFocus())
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { powerMenu.visible = !powerMenu.visible }
        function close(): void { powerMenu.visible = false }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: powerMenu.visible = false
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: powerMenu.visible = false
        Keys.onReturnPressed: powerMenu.run(powerMenu.actions[powerMenu.selected])
        Keys.onLeftPressed: powerMenu.selected = Math.max(0, powerMenu.selected - 1)
        Keys.onRightPressed: powerMenu.selected = Math.min(powerMenu.actions.length - 1, powerMenu.selected + 1)
    }

    Rectangle {
        anchors.centerIn: parent
        width: content.implicitWidth + 32
        height: content.implicitHeight + 24
        color: Colors.black
        border.color: Colors.neon
        border.width: 2
        radius: 8

        MouseArea {
            // swallow clicks so the background MouseArea doesn't close the menu
            anchors.fill: parent
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
}
