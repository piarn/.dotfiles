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
    property var devices: []   // [{mac, name, paired, connected}]
    property bool menuOpen: false
    property bool scanning: false
    property string actionStatus: ""

    function refresh() {
        statusProc.running = true
    }

    // `bluetoothctl devices` (unlike `devices Paired`) also lists anything
    // discovered this boot, paired or not — so a scan just needs to run
    // discovery for a bit and then fall through to the normal refresh().
    function scan() {
        scanning = true
        scanProc.running = true
    }

    function togglePower() {
        powerProc.command = ["bluetoothctl", "power", root.powered ? "off" : "on"]
        powerProc.running = true
    }

    function pair(mac) {
        actionStatus = "pairing…"
        actionProc.command = ["bluetoothctl", "pair", mac]
        actionProc.running = true
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

    // For stale-pairing errors like "br-connection-key-missing" (bluez lost
    // the link key — a re-pair with the same mac won't fix it, since
    // bluetoothctl treats an already-paired device as a no-op). Removing it
    // first drops it back to "discovered but unpaired" so a fresh pair()
    // actually renegotiates a key.
    function forget(mac) {
        actionStatus = "forgetting…"
        actionProc.command = ["bluetoothctl", "remove", mac]
        actionProc.running = true
    }

    Process {
        id: statusProc
        // Fields are "|"-separated, not ":" — a mac address itself contains
        // colons ("80:C3:BA:94:16:1F"), which broke a naive line.split(":")
        // that used to live here (mac would come out as just "80").
        command: ["sh", "-c", `
            powered=$(bluetoothctl show | awk '/Powered:/{print $2}')
            echo "POWERED|$powered"
            bluetoothctl devices | while IFS= read -r line; do
                mac=$(echo "$line" | awk '{print $2}')
                name=$(echo "$line" | cut -d' ' -f3-)
                info=$(bluetoothctl info "$mac")
                paired=$(echo "$info" | grep -q 'Paired: yes' && echo yes || echo no)
                connected=$(echo "$info" | grep -q 'Connected: yes' && echo yes || echo no)
                echo "DEV|$mac|$name|$paired|$connected"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const rows = []
                for (const line of lines) {
                    if (line.startsWith("POWERED|")) {
                        root.powered = line.slice("POWERED|".length) === "yes"
                    } else if (line.startsWith("DEV|")) {
                        const [, mac, name, paired, connected] = line.split("|")
                        rows.push({ mac, name, paired: paired === "yes", connected: connected === "yes" })
                    }
                }
                // Connected, then paired, then just-discovered — so the
                // things you're most likely to act on aren't buried below
                // whatever else the adapter has ever seen.
                rows.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
                root.devices = rows
            }
        }
    }

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onExited: {
            root.scanning = false
            root.refresh()
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
