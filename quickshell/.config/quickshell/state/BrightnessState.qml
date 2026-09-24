// Laptop panel backlight. Read from /sys/class/backlight, written through
// logind's Session.SetBrightness (busctl) — works for the active session
// user without root, udev rules, or brightnessctl. Driven by sway's
// brightness keys via `qs ipc call brightness up|down` (see shell.qml), so
// every change goes through here and can pop the OSD.
pragma Singleton
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string device: ""
    property int max: 0
    property int raw: 0
    readonly property bool available: device !== "" && max > 0
    readonly property real value: available ? raw / max : 0

    // 16 steps, matching the OSD's 16 segments.
    readonly property real step: 1 / 16

    property int pending: -1

    function refresh() {
        readProc.running = true
    }

    function set(v) {
        if (!available) return
        // Never fully off — a black panel with no way to see the OSD is a
        // bad place to land from a key press.
        raw = Math.round(Math.max(0.01, Math.min(1, v)) * max)
        if (writeProc.running) pending = raw
        else write(raw)
    }

    function adjust(delta) {
        // Snap to the step grid so up/down always land on segment edges.
        set(Math.round((value + delta) / step) * step)
        OsdState.show("brightness", value, false)
    }

    function write(r) {
        writeProc.command = ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
            "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", device, String(r)]
        writeProc.running = true
    }

    Process {
        id: readProc
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/max_brightness\" ] || continue; echo \"${d##*/} $(cat \"$d/max_brightness\") $(cat \"$d/brightness\")\"; break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [dev, max, cur] = text.trim().split(" ")
                if (!dev) return
                root.device = dev
                root.max = parseInt(max) || 0
                root.raw = parseInt(cur) || 0
            }
        }
    }

    Process {
        id: writeProc
        onExited: {
            if (root.pending >= 0) {
                const r = root.pending
                root.pending = -1
                root.write(r)
            }
        }
    }
}
