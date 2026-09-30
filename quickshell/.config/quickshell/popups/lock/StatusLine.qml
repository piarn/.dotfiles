// The lock screen's bottom bar, laid out like tmux's status line (dot +
// name on the left, │-separated segments on the right). Display only:
// LockScreen.qml feeds it, so it can also be rendered outside a session
// lock for previews.
import QtQuick
import quickshell
import "../../components"

Rectangle {
    id: root

    property string host: ""
    property string lockedFor: ""
    property string uptime: ""

    property string netGlyph: ""
    property string netLabel: ""        // SSID, "wired", or "offline"
    property var vpns: []               // names of the VPNs that are up
    property int newNotifications: 0    // arrived since locking; count only

    property real battery: -1           // 0..1, or -1 without a battery
    property bool charging: false
    property string batteryGlyph: ""

    implicitHeight: 28
    color: Colors.black

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Style.border
        color: Colors.dim
    }

    component Sep: MonoText { text: "│"; color: Colors.dim }

    Row {
        anchors { left: parent.left; leftMargin: Style.pad; verticalCenter: parent.verticalCenter }
        spacing: Style.gap

        MonoText { text: "●"; color: Colors.acid }
        MonoText { text: root.host; font.bold: true }
        Sep {}
        MonoText { text: "locked " + root.lockedFor; color: Colors.gray2 }
        Sep {}
        MonoText { text: "up " + root.uptime; color: Colors.gray2 }
    }

    Row {
        anchors { right: parent.right; rightMargin: Style.pad; verticalCenter: parent.verticalCenter }
        spacing: Style.gap

        Icon {
            text: root.netGlyph
            color: root.netLabel === "offline" ? Colors.red : Colors.acid
            anchors.verticalCenter: parent.verticalCenter
        }
        MonoText { text: root.netLabel; color: Colors.gray2 }

        Sep { visible: root.vpns.length > 0 }
        MonoText {
            visible: root.vpns.length > 0
            text: "vpn " + root.vpns.join(" · ")
            color: Colors.acid
        }

        Sep { visible: root.newNotifications > 0 }
        MonoText {
            visible: root.newNotifications > 0
            text: root.newNotifications + " new"
            color: Colors.amber
        }

        Sep { visible: root.battery >= 0 }
        Row {
            visible: root.battery >= 0
            spacing: Style.gap
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                text: root.batteryGlyph
                color: batteryBar.tint
                anchors.verticalCenter: parent.verticalCenter
            }
            // same 16 blocks as the level bars and the volume OSD
            Row {
                id: batteryBar
                readonly property int filled: Math.round(Math.max(0, root.battery) * Style.segments)
                readonly property color tint: root.charging ? Colors.acid
                    : root.battery <= 0.15 ? Colors.red
                    : root.battery <= 0.30 ? Colors.amber : Colors.neon
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: Style.segments
                    Rectangle {
                        width: 5
                        height: 10
                        color: index < batteryBar.filled ? batteryBar.tint : Colors.deep
                    }
                }
            }
            MonoText { text: Math.round(root.battery * 100) + "%"; color: Colors.gray2 }
        }
    }
}
