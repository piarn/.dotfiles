// Focus timer: a countdown started from the hub (tools, or the home
// screen), shown on the bar while it runs and ended with a notification.
// The end time is kept in quickshell's state dir, so a restart (a theme
// switch restarts quickshell) doesn't lose it.
// (No curly braces above the pragma, comments included: quickshell stops
// looking for it at the first one and the singleton silently comes up empty.)
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real endsAt: 0      // epoch ms, 0 when idle
    property int minutes: 0      // the length it was started with
    property int left: 0         // seconds remaining
    readonly property bool running: endsAt > 0

    function start(mins) {
        minutes = mins
        endsAt = Date.now() + mins * 60000
        tick()
        save()
    }

    function stop() {
        endsAt = 0
        left = 0
        save()
    }

    function text() {
        const m = Math.floor(left / 60), s = left % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function tick() {
        if (!running) return
        left = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000))
        if (left > 0) return
        Quickshell.execDetached(["notify-send", "-a", "focus", "focus done",
                                 minutes + " minutes — take a break"])
        stop()
    }

    function save() { file.setText(JSON.stringify({ endsAt, minutes })) }

    Timer {
        interval: 1000
        running: root.running
        repeat: true
        onTriggered: root.tick()
    }

    FileView {
        id: file
        path: Quickshell.statePath("focus.json")
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text())
                root.minutes = s.minutes || 0
                root.endsAt = s.endsAt || 0
                root.tick()
            } catch (e) {}
        }
    }
}
