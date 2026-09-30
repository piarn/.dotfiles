.pragma library
// Island tabs and how names reach them: the tab names themselves, plus the
// old popup/IPC names (quicksettings, battery, bluetooth, commandcenter) so
// sway binds and scripts keep working. No QML types, so
// tests/test-island-routes.sh runs it under node.

const TABS = ["system", "calendar", "notifications", "network", "run", "clipboard"]

const ALIASES = {
    quicksettings: "system",
    battery: "system",
    bluetooth: "network",
    commandcenter: "run"
}

// "" for a name that isn't a tab
function tabFor(name) {
    return TABS.indexOf(name) >= 0 ? name : (ALIASES[name] || "")
}

// the tab `delta` places from `tab`, wrapping; the first tab from none
function step(tab, delta) {
    const i = TABS.indexOf(tab)
    if (i < 0) return TABS[0]
    return TABS[(i + delta + TABS.length) % TABS.length]
}

// tabs you type into, which hold the keyboard for as long as they're open
function wantsKeyboard(tab) {
    return tab === "run" || tab === "clipboard"
}
