// The hub's "style" section: the rice themes, each previewed with its
// wallpaper and palette. Enter applies one through apply-theme, which
// restarts quickshell and so closes the hub on its own.
import QtQuick
import "../../state"

QtObject {
    readonly property string name: "style"
    readonly property string glyph: "\u{f03d8}"

    readonly property var rows: [{ kind: "header", title: "themes" }].concat(
        RiceState.themes.map(t => ({
            kind: "theme",
            group: "theme",
            title: t.name,
            subtitle: t.id === RiceState.currentTheme ? "current theme" : "",
            aliases: "theme rice colors wallpaper " + t.id,
            colors: t.colors,
            wallpaper: t.wallpaper,
            on: t.id === RiceState.currentTheme,
            run: () => RiceState.applyTheme(t.id),
        })))
}
