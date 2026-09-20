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

PanelWindow {
    id: launcher
    visible: false
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // "focusable" alone requests on-demand keyboard focus, which sway only
    // grants after the surface is clicked — so typing right after Mod+D
    // opens it goes to whatever previously had focus. Exclusive grabs it
    // immediately on map.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

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
            // forceActiveFocus() here fires before the surface is actually
            // mapped/focused by the compositor, so it's a no-op — defer it
            // to the next event loop turn via Qt.callLater.
            Qt.callLater(() => input.forceActiveFocus())
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.visible = !launcher.visible }
        function close(): void { launcher.visible = false }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: launcher.visible = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: 480
        height: 360
        color: Colors.black
        border.color: Colors.neon
        border.width: 2
        radius: 6

        MouseArea {
            // swallow clicks so the background MouseArea doesn't close the launcher
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
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
}
