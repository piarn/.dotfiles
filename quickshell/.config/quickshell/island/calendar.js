.pragma library
// Date math for the island's calendar tab (island/tabs/CalendarTab.qml): ISO 8601
// weeks, Monday first. No QML types in here, so tests/test-calendar.sh can
// exercise it with plain node. Months are 0-based, like Date's.

const MONTHS = ["january", "february", "march", "april", "may", "june", "july",
                "august", "september", "october", "november", "december"]

function monthName(month) {
    return MONTHS[month]
}

// Monday = 0 … Sunday = 6
function weekday(date) {
    return (date.getDay() + 6) % 7
}

// ISO week and the year it belongs to: weeks run Monday–Sunday and week 1
// is the one holding the year's first Thursday, so early January can be
// week 52/53 of the year before and late December week 1 of the next.
function isoWeek(date) {
    const thursday = new Date(date.getFullYear(), date.getMonth(), date.getDate() - weekday(date) + 3)
    const jan1 = new Date(thursday.getFullYear(), 0, 1)
    return {
        week: 1 + Math.floor(Math.round((thursday - jan1) / 86400000) / 7),
        year: thursday.getFullYear()
    }
}

// 1 on 1 January (DST-safe: whole days, rounded)
function dayOfYear(date) {
    return 1 + Math.round((new Date(date.getFullYear(), date.getMonth(), date.getDate())
                           - new Date(date.getFullYear(), 0, 1)) / 86400000)
}

// Six Monday-first weeks covering `month` (always six, so the popup never
// changes height between months): [{week, days: [{day, month, year,
// inMonth}] × 7}] × 6, padded with the neighbouring months' days.
function monthGrid(year, month) {
    const first = new Date(year, month, 1)
    const start = new Date(year, month, 1 - weekday(first))
    const weeks = []
    for (let w = 0; w < 6; w++) {
        const days = []
        for (let d = 0; d < 7; d++) {
            const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + w * 7 + d)
            days.push({ day: date.getDate(), month: date.getMonth(), year: date.getFullYear(),
                        inMonth: date.getMonth() === month })
        }
        weeks.push({ week: isoWeek(new Date(days[0].year, days[0].month, days[0].day)).week, days: days })
    }
    return weeks
}
