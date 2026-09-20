// Network popup, opened by clicking the network widget in Bar.qml (toggles
// NetworkState.menuOpen — no IPC needed, both just see the same singleton
// via ../state). Shows current connection + nearby wifi networks,
// click-to-connect with a password fallback for secured networks nmcli
// doesn't already have a profile for.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"

PanelWindow {
    id: menu
    visible: NetworkState.menuOpen
    // Exclusive (not the on-demand "focusable: true") so Escape works right
    // away — on-demand only gets granted after a click lands on this
    // surface, and nothing does since it's opened by clicking the bar
    // instead (see Launcher.qml's identical fix).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // Surface starts below the bar (not at the screen edge) so the bar's
    // own icons stay clickable while this is open — otherwise this
    // fullscreen click-away catcher and the bar's surface both cover that
    // strip, and which one wins the click is stacking-order roulette.
    margins.top: 28

    property string lastAttempted: ""

    onVisibleChanged: {
        if (visible) {
            NetworkState.scan()
            Qt.callLater(() => catcher.forceActiveFocus())
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: NetworkState.menuOpen = false
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: NetworkState.menuOpen = false
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 10
        width: 320
        color: Colors.black
        border.color: Colors.neon
        border.width: 2
        radius: 6
        height: content.implicitHeight + 24

        MouseArea {
            // swallow clicks so they don't fall through to the close-on-click-away area
            anchors.fill: parent
        }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Row {
                width: parent.width
                spacing: 6

                Text {
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 15
                    color: NetworkState.kind === "none" ? Colors.red : Colors.neon
                    text: {
                        if (NetworkState.kind === "wifi") {
                            if (NetworkState.signal >= 75) return "\u{f0928}"
                            if (NetworkState.signal >= 50) return "\u{f0925}"
                            if (NetworkState.signal >= 25) return "\u{f0922}"
                            return "\u{f091f}"
                        }
                        if (NetworkState.kind === "eth") return "\u{f0200}"
                        return "\u{f092d}"
                    }
                }

                Text {
                    width: parent.width - 24
                    font.family: "monospace"
                    font.pixelSize: 13
                    font.bold: true
                    color: Colors.neon
                    text: {
                        if (NetworkState.kind === "wifi")
                            return NetworkState.ssid + " (" + NetworkState.signal + "%) — " + (NetworkState.ip || "no ip")
                        if (NetworkState.kind === "eth")
                            return NetworkState.device + " — " + (NetworkState.ip || "no ip")
                        return "not connected"
                    }
                    wrapMode: Text.Wrap
                }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.dim }

            Item {
                width: parent.width
                height: rescanLabel.implicitHeight

                Text {
                    anchors.left: parent.left
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.gray
                    text: NetworkState.scanning ? "scanning…" : "nearby networks"
                }
                Text {
                    id: rescanLabel
                    anchors.right: parent.right
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.acid
                    text: "[rescan]"
                    MouseArea { anchors.fill: parent; onClicked: NetworkState.scan() }
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: NetworkState.scanResults

                    delegate: Column {
                        required property var modelData
                        required property int index
                        width: content.width
                        spacing: 4

                        Rectangle {
                            width: parent.width
                            height: 28
                            radius: 4
                            color: modelData.active ? Colors.dim : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    color: modelData.active ? Colors.neon : Colors.fg
                                    text: (modelData.security && modelData.security !== "--" ? "🔒 " : "  ") + modelData.ssid
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: "monospace"
                                font.pixelSize: 12
                                color: Colors.gray2
                                text: modelData.signal + "%"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    menu.lastAttempted = modelData.ssid
                                    NetworkState.connectTo(modelData.ssid)
                                }
                            }
                        }

                        Row {
                            visible: menu.lastAttempted === modelData.ssid
                                && NetworkState.connectStatus.startsWith("failed")
                            width: parent.width
                            spacing: 6

                            TextInput {
                                id: pwInput
                                width: 180
                                height: 22
                                font.family: "monospace"
                                font.pixelSize: 12
                                color: Colors.neon
                                clip: true
                                echoMode: TextInput.Password
                                Rectangle { anchors.fill: parent; anchors.margins: -2; z: -1; color: Colors.surface; border.color: Colors.dim; border.width: 1 }
                                Keys.onReturnPressed: NetworkState.connectTo(modelData.ssid, pwInput.text)
                            }

                            Text {
                                font.family: "monospace"
                                font.pixelSize: 12
                                color: Colors.acid
                                text: "[connect]"
                                MouseArea { anchors.fill: parent; onClicked: NetworkState.connectTo(modelData.ssid, pwInput.text) }
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: NetworkState.connectStatus !== ""
                font.family: "monospace"
                font.pixelSize: 12
                color: NetworkState.connectStatus.startsWith("failed") ? Colors.red : Colors.acid
                text: NetworkState.connectStatus
                wrapMode: Text.Wrap
            }
        }
    }
}
