.pragma library
// Small formatting helpers shared by island tabs. No QML types, so
// tests/test-island-helpers.sh runs it under node.

// "now", "5m", "3h", "2d" since `then` (ms), as of `now` (ms)
function ago(then, now) {
    const s = Math.max(0, (now - then) / 1000)
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    return Math.floor(s / 86400) + "d"
}

// how far through its year `date` is, 0..100 (whole percent)
function yearProgress(date) {
    const start = new Date(date.getFullYear(), 0, 1)
    const end = new Date(date.getFullYear() + 1, 0, 1)
    return Math.round((date - start) / (end - start) * 100)
}

// "HH:MM" from Open-Meteo's local ISO time ("2026-09-30T07:12")
function hhmm(iso) {
    return iso ? iso.slice(11, 16) : ""
}

// "11h 51m" between two such times
function daylight(rise, set) {
    const mins = Math.round((new Date(set) - new Date(rise)) / 60000)
    return Math.floor(mins / 60) + "h " + (mins % 60) + "m"
}

// [{key, items}] in the order each key first appears (items keep theirs)
function groupBy(items, keyOf) {
    const groups = []
    const index = {}
    for (const item of items) {
        const k = keyOf(item)
        if (index[k] === undefined) {
            index[k] = groups.length
            groups.push({ key: k, items: [] })
        }
        groups[index[k]].items.push(item)
    }
    return groups
}
