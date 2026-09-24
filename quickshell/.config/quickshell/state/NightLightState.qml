// Night light from the quick settings tile: while `active`, keeps wlsunset
// running pinned at `temperature` (low/high temps 1K apart, so it ignores
// the time of day). wlroots resets the gamma when the process exits, so
// turning it off — or quickshell restarting — restores normal colours.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool active: false
    property bool available: false
    readonly property int temperature: 4000

    Process {
        running: root.active && root.available
        command: ["wlsunset", "-t", String(root.temperature), "-T", String(root.temperature + 1)]
        onExited: (code) => { if (code !== 0) root.active = false }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v wlsunset"]
        onExited: (code) => root.available = code === 0
    }
}
