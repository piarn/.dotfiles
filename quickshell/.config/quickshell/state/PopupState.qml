// Which bar popup is open, and on which screen. At most one popup is open
// at a time; components/BarPopup.qml binds its visibility to `current` and
// its output to `screen`, so a popup opens on the monitor whose bar was
// clicked instead of wherever sway's focus happens to be (clicking a
// layer-shell bar doesn't move output focus).
pragma Singleton
import Quickshell
import Quickshell.I3
import QtQuick

QtObject {
    id: root

    property string current: ""
    property var screen: null

    // The ShellScreen sway currently has focused — for things opened from
    // the keyboard (IPC) or on their own (toasts, OSD), where there's no
    // click to take the screen from.
    readonly property var focusedScreen: {
        const mon = I3.focusedMonitor
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (mon && screens[i].name === mon.name) return screens[i]
        return screens.length ? screens[0] : null
    }

    function isOpen(name) {
        return current === name
    }

    // `scr` is the bar's screen when clicked, omitted from IPC. Clicking the
    // same widget on another monitor moves the popup there instead of
    // closing it.
    function toggle(name, scr) {
        const target = scr || focusedScreen
        if (current === name && screen === target) {
            current = ""
            return
        }
        // Close first so the old popup doesn't briefly hop to the new
        // screen before hiding.
        current = ""
        screen = target
        current = name
    }

    function close() {
        current = ""
    }
}
