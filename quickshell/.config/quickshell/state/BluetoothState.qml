// Bluetooth status, polled via bluetoothctl (same shell-out pattern as
// NetworkState) rather than the native Quickshell.Bluetooth module: in
// testing, Bluetooth.devices/Bluetooth.adapters (Quickshell 0.2.1) never
// populated even minutes after the C++ side logged the adapter/device as
// tracked (--vv showed "Tracked new adapter"/"Tracked new device" but
// Bluetooth.adapters.values.length stayed 0) — a bug or a timing quirk
// either way, so this sticks to the CLI, which is instant and reliable.
pragma Singleton
import Quickshell.Io
import QtQuick

Item {
    id: root

    property bool powered: false
    property var devices: []   // [{mac, name, connected}]
    property bool menuOpen: false
    property string actionStatus: ""

    function refresh() {
        statusProc.running = true
    }

    function togglePower() {
        powerProc.command = ["bluetoothctl", "power", root.powered ? "off" : "on"]
        powerProc.running = true
    }

    function connectTo(mac) {
        actionStatus = "connecting…"
        actionProc.command = ["bluetoothctl", "connect", mac]
        actionProc.running = true
    }

    function disconnectFrom(mac) {
        actionStatus = "disconnecting…"
        actionProc.command = ["bluetoothctl", "disconnect", mac]
        actionProc.running = true
    }

    Process {
        id: statusProc
        command: ["sh", "-c", `
            powered=$(bluetoothctl show | awk '/Powered:/{print $2}')
            echo "POWERED:$powered"
            bluetoothctl devices Paired | while IFS= read -r line; do
                mac=$(echo "$line" | awk '{print $2}')
                name=$(echo "$line" | cut -d' ' -f3-)
                connected=$(bluetoothctl info "$mac" | grep -q 'Connected: yes' && echo yes || echo no)
                echo "DEV:$mac:$name:$connected"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const rows = []
                for (const line of lines) {
                    if (line.startsWith("POWERED:")) {
                        root.powered = line.slice("POWERED:".length) === "yes"
                    } else if (line.startsWith("DEV:")) {
                        const [, mac, name, connected] = line.split(":")
                        rows.push({ mac, name, connected: connected === "yes" })
                    }
                }
                root.devices = rows
            }
        }
    }

    Process {
        id: powerProc
        onExited: root.refresh()
    }

    Process {
        id: actionProc
        stdout: StdioCollector { id: actionStdout }
        onExited: (exitCode) => {
            root.actionStatus = exitCode === 0 ? "" : "failed: " + actionStdout.text.trim().split("\n").pop()
            root.refresh()
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
