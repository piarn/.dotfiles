// App launcher, replacing wofi. Hidden by default; toggled from sway via
// `bindsym $mod+d exec qs ipc call launcher toggle` (see
// ~/.dots/sway/.config/sway/config) instead of a global shortcut, since
// wlroots compositors like sway don't expose one to arbitrary clients.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import quickshell
import "../components"

CardWindow {
    id: launcher
    visible: false
    centered: true
    needsKeyboard: true
    cardWidth: 480
    cardHeight: body.implicitHeight + 24
    initialFocus: input
    WlrLayershell.namespace: "quickshell-launcher"
    onDismissed: launcher.visible = false

    property string query: ""
    readonly property var results: {
        const q = query.toLowerCase()
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && (q === "" || e.name.toLowerCase().includes(q)))
            .slice(0, 8)
    }
    property int selected: 0

    function launch(entry) {
        if (entry) entry.execute()
        launcher.visible = false
    }

    onVisibleChanged: {
        if (visible) {
            query = ""
            selected = 0
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.visible = !launcher.visible }
        function close(): void { launcher.visible = false }
    }

    Column {
        id: body
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8

        Rectangle {
            width: parent.width
            height: 34
            color: Colors.black
            border.color: Colors.dim
            border.width: 1

            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: 6
                color: Colors.neon
                font.family: "monospace"
                font.pixelSize: 14
                clip: true
                text: launcher.query
                onTextChanged: {
                    launcher.query = text
                    launcher.selected = 0
                }

                Keys.onEscapePressed: launcher.visible = false
                Keys.onReturnPressed: launcher.launch(launcher.results[launcher.selected])
                Keys.onDownPressed: launcher.selected = Math.min(launcher.selected + 1, launcher.results.length - 1)
                Keys.onUpPressed: launcher.selected = Math.max(launcher.selected - 1, 0)
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: launcher.results

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 40
                    radius: 4
                    color: index === launcher.selected ? Colors.dim : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 28
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            font.family: "monospace"
                            font.pixelSize: 14
                            color: index === launcher.selected ? Colors.neon : Colors.fg
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: launcher.launch(modelData)
                    }
                }
            }
        }
    }
}
