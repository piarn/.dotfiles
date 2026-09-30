// Base for the island's tabs: a Column shown while it's the open tab. Keeps
// the names the old popups used (innerWidth, screen, opened(), close(),
// openPopup()), so their bodies moved over unchanged.
import QtQuick
import "../state"

Column {
    id: tab

    required property string name
    readonly property bool shown: IslandState.tab === name
    readonly property var screen: IslandState.screen
    readonly property int innerWidth: width
    // on top of run/clipboard, which always want it: e.g. a password field
    property bool needsKeyboard: false
    // what gets keyboard focus when the tab opens (null: the island itself)
    property Item initialFocus: null

    signal opened()

    // Keys while the island itself has focus (no text field): a tab with a
    // list overrides this for ↑/↓/j/k, Enter, Delete. true = handled.
    function handleKey(event) { return false }

    function close() { IslandState.close() }
    function openPopup(name) { IslandState.open(name, screen) }
    // keyboard focus back to the island (h/l, Esc), e.g. when a form closes
    function focusCatcher() { IslandState.panelFocusRequested() }

    visible: shown
    spacing: 10
    onShownChanged: if (shown) opened()
}
