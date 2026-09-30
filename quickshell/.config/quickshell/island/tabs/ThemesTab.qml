// The island's themes tab: every ~/.rice theme as a row like the run tab's
// `:theme` results (run/ResultRow, kind "theme"): wallpaper thumbnail, name
// and palette, the current one marked ●. ↑/↓ or j/k select (it opens on the
// current theme), Enter or a click applies it — ~/.rice/bin/apply-theme
// re-renders every app's theme and restarts quickshell, so the island
// comes back collapsed in the new colours. Same list as `:theme`
// (state/RiceState.qml).
import QtQuick
import quickshell
import "../../state"
import "../../components"
import ".."
import "run"

Tab {
    id: menu
    name: "themes"
    spacing: 8

    property int selected: 0

    function selectCurrent() {
        selected = Math.max(0, RiceState.themes.findIndex(t => t.id === RiceState.currentTheme))
    }
    function apply(t) {
        if (t.id !== RiceState.currentTheme) RiceState.applyTheme(t.id)
    }

    onOpened: {
        RiceState.refresh()
        selectCurrent()
    }
    Connections {
        target: RiceState
        function onThemesChanged() { menu.selectCurrent() }
    }

    function handleKey(event) {
        const n = RiceState.themes.length
        if (!n) return false
        if (event.key === Qt.Key_Down || event.key === Qt.Key_J) selected = Math.min(n - 1, selected + 1)
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) selected = Math.max(0, selected - 1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) apply(RiceState.themes[selected])
        else return false
        return true
    }

    SectionHeader {
        title: "themes"
        count: String(RiceState.themes.length)
    }

    Column {
        width: menu.width
        spacing: 2

        Repeater {
            model: RiceState.themes

            delegate: ResultRow {
                required property var modelData
                required property int index
                readonly property bool isCurrent: modelData.id === RiceState.currentTheme
                width: menu.width
                item: ({ kind: "theme", title: modelData.name, colors: modelData.colors, wallpaper: modelData.wallpaper,
                         subtitle: isCurrent ? "current theme" : "", on: isCurrent })
                current: index === menu.selected
                onClicked: menu.apply(modelData)
            }
        }
    }

    MonoText {
        font.pixelSize: 11
        color: Colors.gray2
        text: "↑↓/jk select · enter or click applies"
    }
}
