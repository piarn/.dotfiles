// Notification list, opened by clicking the bell+dot widget in Bar.qml's
// right-hand widget group (after battery) — the dot there is solid/hollow
// depending on whether there's anything to see; this popup is where you
// actually read/dismiss it, and mute/unmute lives here too. Same PanelWindow
// shape as every other bar popup (NetworkMenu/BatteryMenu/...): fullscreen
// transparent window, Escape/click-away to close, one themed card anchored
// top-right like BatteryMenu, since that's the corner the bell lives in now.
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"

PanelWindow {
    id: menu
    visible: NotificationState.menuOpen
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins.top: 28

    onVisibleChanged: {
        if (visible) Qt.callLater(() => catcher.forceActiveFocus())
    }

    MouseArea {
        anchors.fill: parent
        onClicked: NotificationState.menuOpen = false
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: NotificationState.menuOpen = false
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 10
        width: 340
        height: content.implicitHeight + 20
        color: Colors.black
        border.color: Colors.neon
        border.width: 2
        radius: 6

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 8

            Row {
                width: parent.width
                spacing: 12

                Text {
                    width: parent.width - muteToggle.implicitWidth - (clearAll.visible ? clearAll.implicitWidth + 12 : 0) - 12
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.gray
                    text: "notifications"
                }

                Text {
                    id: muteToggle
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: NotificationState.muted ? Colors.red : Colors.neon
                    text: NotificationState.muted ? "[unmute]" : "[mute]"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: NotificationState.toggleMute()
                    }
                }

                Text {
                    id: clearAll
                    visible: NotificationState.notifications.length > 0
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.neon
                    text: "[clear all]"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: NotificationState.clearAll()
                    }
                }
            }

            Text {
                visible: NotificationState.notifications.length === 0
                width: parent.width
                font.family: "monospace"
                font.pixelSize: 13
                color: Colors.gray
                text: "nothing here"
            }

            Repeater {
                model: NotificationState.notifications

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: content.width
                    height: rowContent.implicitHeight + 12
                    radius: 4
                    color: Colors.surface
                    border.width: 1
                    border.color: row.modelData.urgency === NotificationUrgency.Critical ? Colors.red : Colors.dim

                    Column {
                        id: rowContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 8
                        spacing: 2

                        Row {
                            width: parent.width

                            Text {
                                width: parent.width - dismiss.implicitWidth
                                font.family: "monospace"
                                font.bold: true
                                font.pixelSize: 13
                                color: Colors.fg
                                elide: Text.ElideRight
                                text: (row.modelData.appName || "notification") + (row.modelData.summary ? " — " + row.modelData.summary : "")
                            }

                            Text {
                                id: dismiss
                                font.family: "monospace"
                                font.pixelSize: 12
                                color: Colors.red
                                text: "[x]"

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: NotificationState.dismiss(row.modelData)
                                }
                            }
                        }

                        Text {
                            visible: row.modelData.body.length > 0
                            width: parent.width
                            font.family: "monospace"
                            font.pixelSize: 12
                            color: Colors.gray
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            text: row.modelData.body
                        }
                    }
                }
            }
        }
    }
}
