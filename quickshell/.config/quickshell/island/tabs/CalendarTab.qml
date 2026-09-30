// The island's calendar tab (click the clock): a month grid with ISO week
// numbers, Monday first (the math is in island/calendar.js): ‹ › or the
// scroll wheel change month, the title jumps back to today, and it always
// opens on the current month. The current weather sits under the grid.
import QtQuick
import quickshell
import "../../state"
import "../../components"
import ".."
import "../calendar.js" as Cal

Tab {
    id: menu
    name: "calendar"

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()

    readonly property var grid: Cal.monthGrid(year, month)
    readonly property int cell: 40

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
        running: menu.shown
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

    // current weather (state/WeatherState.qml), gone when stale
    Row {
        visible: WeatherState.available
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.gray2
            text: WeatherState.glyph
        }
        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.gray2
            text: WeatherState.temp + " " + WeatherState.desc + (WeatherState.data ? " · " + WeatherState.data.city.toLowerCase() : "")
        }
    }
}
