// The island's calendar tab (click the clock): a month grid with ISO week
// numbers, Monday first (the math is in island/calendar.js): ‹ › or the
// scroll wheel change month, [today] jumps back, and it always opens on
// the current month. Under the grid, rows like the network tab's: the
// weather, sunrise → sunset (state/WeatherState.qml, from dots-weather),
// and how far through the year today is.
import QtQuick
import quickshell
import "../../state"
import "../../components"
import ".."
import "../calendar.js" as Cal
import "../format.js" as Fmt

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

    // september 2026 · week 40            [‹] [today] [›]
    SectionHeader {
        title: Cal.monthName(menu.month) + " " + menu.year
        count: menu.year === menu.today.getFullYear() && menu.month === menu.today.getMonth()
            ? "week " + Cal.isoWeek(menu.today).week : ""

        TextButton { label: "‹"; onClicked: menu.shift(-1) }
        TextButton { label: "today"; onClicked: menu.goToday() }
        TextButton { label: "›"; onClicked: menu.shift(1) }
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

    Divider {}

    // today, as rows like the network tab's: weather, the sun, the year
    component InfoRow: Item {
        property alias glyph: glyphIcon.text
        property alias title: titleText.text
        property alias subtitle: subText.text
        width: parent ? parent.width : 0
        height: 30

        Icon {
            id: glyphIcon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 18
            color: Colors.gray2
        }
        MonoText {
            id: titleText
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.fg
        }
        MonoText {
            id: subText
            anchors.left: titleText.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.gray
        }
    }

    InfoRow {
        visible: WeatherState.available
        glyph: WeatherState.glyph
        title: WeatherState.temp + " " + WeatherState.desc
        subtitle: WeatherState.data && WeatherState.data.city ? WeatherState.data.city.toLowerCase() : ""
    }
    InfoRow {
        visible: WeatherState.sunrise !== "" && WeatherState.sunset !== ""
        glyph: "\u{e1c6}"   // wb_twilight
        title: Fmt.hhmm(WeatherState.sunrise) + " → " + Fmt.hhmm(WeatherState.sunset)
        subtitle: visible ? Fmt.daylight(WeatherState.sunrise, WeatherState.sunset) + " of daylight" : ""
    }
    InfoRow {
        glyph: "\u{ea5c}"   // hourglass_bottom
        title: Qt.formatDate(menu.today, "dddd").toLowerCase() + " · day " + Cal.dayOfYear(menu.today)
        subtitle: Fmt.yearProgress(menu.today) + "% of " + menu.today.getFullYear()
    }
}
