// What the launcher has launched, so frequent and recent picks float to
// the top. Kept as key -> count and last-use time in quickshell's
// per-shell state dir; each use's weight halves every two weeks, so an
// app you stopped using sinks back down on its own.
// (No curly braces above the pragma, comments included: quickshell stops
// looking for it at the first one and the singleton silently comes up empty.)
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var uses: ({})
    readonly property real halfLifeMs: 14 * 24 * 3600 * 1000

    // 0 for never used; grows with frequency, shrinks with age.
    function weight(key) {
        const u = uses[key]
        if (!u) return 0
        return u.n * Math.pow(0.5, (Date.now() - u.t) / halfLifeMs)
    }

    function record(key) {
        const next = Object.assign({}, uses)
        // fold the decay into the stored count so it stays meaningful
        next[key] = { n: weight(key) + 1, t: Date.now() }
        uses = next
        file.setText(JSON.stringify(uses))
    }

    FileView {
        id: file
        path: Quickshell.statePath("launcher-usage.json")
        printErrors: false
        onLoaded: {
            try { root.uses = JSON.parse(text()) || {} } catch (e) { root.uses = {} }
        }
    }
}
