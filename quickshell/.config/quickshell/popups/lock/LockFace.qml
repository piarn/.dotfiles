// What one screen of the lock shows: a seven-segment clock, the date, the
// password as 16 cells that light up per character, and under it the
// tmux-style StatusLine. It owns the (invisible) text field keystrokes go
// to but none of the authentication — LockScreen.qml wires `text`,
// `accepted` and the state properties to PamContext — so it can be
// rendered in an ordinary window for previews.
import QtQuick
import quickshell
import "../../components"

Rectangle {
    id: root

    property date now: new Date()
    property bool busy: false        // PAM is checking the password
    property bool failed: false      // last attempt was wrong
    property string status: ""

    property alias text: input.text
    property alias input: input
    property alias statusLine: statusLine
    signal accepted()

    color: Colors.black

    function focusInput() { input.forceActiveFocus() }
    // flash + shake the password cells (a wrong password)
    function reject() { rejectAnim.restart() }

    // clicking anywhere gives the field its focus back
    MouseArea { anchors.fill: parent; onClicked: root.focusInput() }

    Column {
        anchors.centerIn: parent
        spacing: 36

        // HH:MM, the colon blinking with the seconds
        Row {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            readonly property int h: root.now.getHours()
            readonly property int m: root.now.getMinutes()

            SegmentDigit { value: Math.floor(clock.h / 10) }
            SegmentDigit { value: clock.h % 10 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 40
                Repeater {
                    model: 2
                    Rectangle {
                        width: 13
                        height: 13
                        color: root.now.getSeconds() % 2 === 0 ? Colors.neon : Colors.deep
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }
            SegmentDigit { value: Math.floor(clock.m / 10) }
            SegmentDigit { value: clock.m % 10 }
        }

        MonoText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 14
            font.letterSpacing: 2
            color: Colors.gray2
            text: Qt.formatDate(root.now, "dddd · d MMMM").toLowerCase()
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Item {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: cells.width + Style.marker + Style.pad
                height: 16

                // the accent rule every focused/active thing in the shell has
                Rectangle {
                    width: Style.marker
                    height: parent.height
                    color: root.failed ? Colors.red : input.activeFocus ? Colors.neon : Colors.dim
                }

                Row {
                    id: cells
                    x: Style.marker + Style.pad
                    spacing: 4

                    readonly property int filled: Math.min(input.length, Style.segments)
                    property bool flash: false

                    Repeater {
                        model: Style.segments
                        Rectangle {
                            width: 14
                            height: 16
                            color: cells.flash ? Colors.red
                                : root.busy && index < cells.filled ? Colors.acid
                                : index < cells.filled ? Colors.neon : Colors.deep
                            Behavior on color { ColorAnimation { duration: Style.fast } }
                        }
                    }
                }

                // Keystrokes land here; what's shown is only the cells above.
                TextInput {
                    id: input
                    width: 1
                    height: 1
                    opacity: 0
                    echoMode: TextInput.Password
                    enabled: !root.busy
                    Keys.onReturnPressed: root.accepted()
                    Keys.onEnterPressed: root.accepted()
                }

                SequentialAnimation {
                    id: rejectAnim
                    PropertyAction { target: cells; property: "flash"; value: true }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -6; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
                    PauseAnimation { duration: 400 }
                    PropertyAction { target: cells; property: "flash"; value: false }
                }
            }

            // Fixed size: a Column skips zero-width items, so an empty
            // status would otherwise shift everything when a message appears.
            MonoText {
                width: field.width
                height: 16
                horizontalAlignment: Text.AlignHCenter
                color: root.failed ? Colors.red : Colors.amber
                text: root.busy ? "verifying…"
                    : root.status !== "" ? root.status
                    : input.length > Style.segments ? input.length + " chars" : ""
            }
        }

        StatusLine {
            id: statusLine
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

}
