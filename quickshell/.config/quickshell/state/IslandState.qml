// Which island tab is open, and on which screen ("" = collapsed). Replaces
// the old per-popup PopupState: every popup is an island tab now (see
// island/Island.qml). Names go through island/routes.js, so the old popup
// and IPC names (quicksettings, battery, bluetooth, commandcenter) still
// work.
pragma Singleton
import Quickshell
import Quickshell.I3
import QtQuick
import "../island/routes.js" as Routes

QtObject {
    id: root

    property string tab: ""
    property var screen: null
    readonly property bool grown: tab !== ""
    // run and clipboard hold the keyboard for as long as they're open
    readonly property bool wantsKeyboard: Routes.wantsKeyboard(tab)

    readonly property var focusedScreen: {
        const mon = I3.focusedMonitor
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (mon && screens[i].name === mon.name) return screens[i]
        return screens.length ? screens[0] : null
    }

    function open(name, scr) {
        const t = Routes.tabFor(name)
        if (!t) return
        screen = scr || focusedScreen
        tab = t
    }

    // what the run tab's search field starts with next time it opens, e.g.
    // ":" for the session actions ($mod+Shift+Escape, [power])
    property string runPrefix: ""

    function openRun(prefix, scr) {
        runPrefix = prefix || ""
        open("run", scr)
    }

    // the same tab on the same screen again collapses it
    function toggle(name, scr) {
        const t = Routes.tabFor(name)
        const target = scr || focusedScreen
        if (!t) return
        if (tab === t && screen === target) {
            close()
            return
        }
        screen = target
        tab = t
    }

    // a tab handing keyboard focus back to the island itself (island/Panel.qml)
    signal panelFocusRequested()

    function close() {
        tab = ""
    }

    function step(delta) {
        if (grown) tab = Routes.step(tab, delta)
    }
}
