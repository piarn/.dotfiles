// Calendar and notifications, opened from the clock in the middle of the
// bar (and `qs ipc call popup toggle calendar`; "notifications" still
// works). A month grid with ISO week numbers, Monday first (the math is in
// calendar/calendar.js): ‹ › or the scroll wheel change month, the title
// jumps back to today, and it always opens on the current month. Below it,
// every notification until dismissed (toasts are just the on-screen subset,
// see NotificationToasts.qml), with do-not-disturb.
import QtQuick
import quickshell
import "../state"
import "../components"
import "calendar/calendar.js" as Cal

BarPopup {
    id: menu
    name: "calendar"
    fixedWidth: 300
    topCenter: true

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()

    readonly property var grid: Cal.monthGrid(year, month)
    readonly property int cell: 30

    function shift(months) {
        const d = new Date(year, month + months, 1)
        year = d.getFullYear()
        month = d.getMonth()
    }
    function goToday() {
        today = new Date()
        year = today.getFullYear()
        month = today.getMonth()
    }
    function isToday(d) {
        return d.day === today.getDate() && d.month === today.getMonth() && d.year === today.getFullYear()
    }

    onOpened: goToday()

    // midnight passing while it's open
    Timer {
        running: menu.visible
        interval: 60 * 1000
        repeat: true
        onTriggered: menu.today = new Date()
    }

    // ‹ september 2026 ›
    Item {
        width: parent.width
        height: title.implicitHeight

        TextButton {
            anchors.left: parent.left
            label: "‹"
            onClicked: menu.shift(-1)
        }
        MonoText {
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 13
            font.bold: true
            color: titleMouse.containsMouse ? Colors.fg : Colors.neon
            text: Cal.monthName(menu.month) + " " + menu.year

            MouseArea {
                id: titleMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menu.goToday()
            }
        }
        TextButton {
            anchors.right: parent.right
            label: "›"
            onClicked: menu.shift(1)
        }
    }

    // week column + seven days, six rows (height never changes between months)
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Row {
            Repeater {
                model: ["wk", "mo", "tu", "we", "th", "fr", "sa", "su"]
                MonoText {
                    required property string modelData
                    required property int index
                    width: menu.cell
                    horizontalAlignment: Text.AlignHCenter
                    color: index === 0 ? Colors.dim : index >= 6 ? Colors.gray : Colors.gray2
                    text: modelData
                }
            }
        }

        Repeater {
            model: menu.grid

            Row {
                required property var modelData

                MonoText {
                    width: menu.cell
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Colors.dim
                    text: modelData.week
                }

                Repeater {
                    model: modelData.days

                    // today inverted, like tmux's current window
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool today: menu.isToday(modelData)
                        width: menu.cell
                        height: 22
                        color: today ? Colors.neon : "transparent"

                        MonoText {
                            anchors.centerIn: parent
                            font.bold: parent.today
                            color: parent.today ? Colors.black
                                : !modelData.inMonth ? Colors.dim
                                : parent.index >= 5 ? Colors.gray2 : Colors.fg
                            text: modelData.day
                        }
                    }
                }
            }
        }

        WheelHandler {
            onWheel: (event) => menu.shift(event.angleDelta.y > 0 ? -1 : 1)
        }
    }

    MonoText {
        anchors.horizontalCenter: parent.horizontalCenter
        color: Colors.gray2
        text: Qt.formatDate(menu.today, "dddd").toLowerCase()
            + " · week " + Cal.isoWeek(menu.today).week
            + " · day " + Cal.dayOfYear(menu.today)
    }

    Divider {}

    // notifications
    Item {
        width: parent.width
        height: dndBtn.implicitHeight

        MonoText {
            anchors.left: parent.left
            color: Colors.gray
            text: "notifications" + (NotificationState.notifications.length ? " · " + NotificationState.notifications.length : "")
        }

        Row {
            anchors.right: parent.right
            spacing: 12

            // do-not-disturb: hides toasts; critical ones still break through
            TextButton {
                id: dndBtn
                label: NotificationState.dnd ? "silenced" : "silence"
                baseColor: NotificationState.dnd ? Colors.red : Colors.acid
                onClicked: NotificationState.toggleDnd()
            }
            TextButton {
                visible: NotificationState.notifications.length > 0
                label: "clear all"
                onClicked: NotificationState.clearAll()
            }
        }
    }

    MonoText {
        visible: NotificationState.notifications.length === 0
        font.pixelSize: 13
        color: Colors.gray
        text: "nothing here"
    }

    // Scrolls once the list outgrows half the screen (the calendar takes
    // the top of the card).
    Flickable {
        width: parent.width
        height: Math.min(list.implicitHeight, (menu.screen ? menu.screen.height : 1080) * 0.5)
        visible: NotificationState.notifications.length > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 6

            Repeater {
                // newest first
                model: NotificationState.notifications.slice().reverse()

                delegate: NotificationCard {
                    required property var modelData
                    width: list.width
                    notification: modelData
                }
            }
        }
    }
}
