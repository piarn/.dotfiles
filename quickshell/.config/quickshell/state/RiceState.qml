// What ~/.rice offers and what's active: themes (with their palette and
// wallpaper, for previews), screen layouts, and the current pick of each.
// Read with one python3 pass (tomllib) on refresh() — run once at startup
// (Component.onCompleted) so the command center's `:theme`/`:layout` mode
// has data without needing anything to open first; applying goes through
// ~/.rice/bin/apply-* like everywhere else. A theme switch restarts
// quickshell (apply-theme), so only a layout switch needs the refresh
// afterwards.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.rice"

    property var themes: []     // [{id, name, colors: {role: "#rrggbb"}, wallpaper}]
    property var layouts: []    // [id]
    property string currentTheme: ""
    property string currentLayout: ""

    function refresh() { readProc.running = true }

    function applyTheme(id) { Quickshell.execDetached([dir + "/bin/apply-theme", id]) }

    function applyLayout(id) {
        applyProc.command = [dir + "/bin/apply-layout", id]
        applyProc.running = true
    }

    Process {
        id: applyProc
        onExited: root.refresh()
    }

    Process {
        id: readProc
        command: ["python3", "-c", `
import json, os, sys, tomllib
d = sys.argv[1]
def first(p):
    try:
        return open(p).readline().strip()
    except OSError:
        return ""
themes = []
for t in sorted(os.listdir(d + "/themes")):
    p = d + "/themes/" + t
    try:
        doc = tomllib.load(open(p + "/theme.toml", "rb"))
    except (OSError, tomllib.TOMLDecodeError):
        continue
    wall = next((p + "/" + f for f in sorted(os.listdir(p)) if f.startswith("wallpaper.")), "")
    themes.append({"id": t, "name": doc.get("name", t), "colors": doc.get("colors", {}), "wallpaper": wall})
layouts = sorted(f[:-5] for f in os.listdir(d + "/layouts") if f.endswith(".conf"))
print(json.dumps({"themes": themes, "layouts": layouts,
                  "theme": first(d + "/themes/current"), "layout": first(d + "/layouts/current")}))
`, dir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text)
                    root.themes = r.themes
                    root.layouts = r.layouts
                    root.currentTheme = r.theme
                    root.currentLayout = r.layout
                } catch (e) {
                    console.warn("RiceState: " + e)
                }
            }
        }
    }

    Component.onCompleted: refresh()
}
