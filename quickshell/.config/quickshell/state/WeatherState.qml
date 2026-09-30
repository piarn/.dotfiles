// Current weather for the bar's clock pill and the lock screen, read from
// the cache ~/.local/bin/dots-weather writes (dots-weather.timer, every 30
// minutes). Never touches the network itself, so nothing that shows it can
// hang on a slow or dead weather service. Hidden when there's no cache
// (no city set in ~/.config/dots/weather.conf) or it's over 3 hours old.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int maxAge: 3 * 60 * 60

    property var data: null
    property int now: Date.now() / 1000

    readonly property bool available: data !== null && now - data.updated < maxAge
    readonly property string glyph: available ? data.glyph : ""
    readonly property string temp: available ? data.temp + "°" : ""
    readonly property string desc: available ? data.desc : ""

    FileView {
        id: cache
        path: Quickshell.env("HOME") + "/.cache/dots/weather.json"
        printErrors: false
        onLoaded: {
            try { root.data = JSON.parse(text()) } catch (e) { root.data = null }
        }
        onLoadFailed: root.data = null
    }

    // re-read once a minute: cheap, and needs no file watch on a cache that
    // may not exist yet
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now() / 1000
            cache.reload()
        }
    }
}
