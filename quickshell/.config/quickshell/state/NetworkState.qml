// Shared network status, polled once here (not per-screen) and read by both
// Bar.qml's status text and popups/NetworkMenu.qml's popup — both pull it in
// via `import "./state"` / `import "../state"`; no IPC needed since it's the
// same QML singleton either way.
pragma Singleton
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string kind: "none"   // "wifi" | "eth" | "none"
    property string device: ""
    property string ssid: ""
    property int signal: 0
    property string ip: ""

    property bool menuOpen: false
    property var scanResults: []   // [{ssid, signal, security, active}]
    property bool scanning: false
    property string connectStatus: ""

    function refresh() {
        statusProc.running = true
    }

    function scan() {
        scanning = true
        scanProc.running = true
    }

    function connectTo(ssid, password) {
        connectStatus = "connecting…"
        connectProc.command = password
            ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "device", "wifi", "connect", ssid]
        connectProc.targetSsid = ssid
        connectProc.running = true
    }

    Process {
        id: statusProc
        command: ["sh", "-c", `
            row=$(nmcli -t -f TYPE,DEVICE con show --active 2>/dev/null | grep -v '^loopback:' | head -1)
            kind=$(echo "$row" | cut -d: -f1)
            dev=$(echo "$row" | cut -d: -f2)
            ip=$(nmcli -t -f IP4.ADDRESS dev show "$dev" 2>/dev/null | head -1 | cut -d: -f2 | cut -d/ -f1)
            case "$kind" in
                *wireless*)
                    info=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2":"$3; exit}')
                    echo "wifi:$dev:$(echo "$info" | cut -d: -f1):$(echo "$info" | cut -d: -f2):$ip"
                    ;;
                *ethernet*)
                    echo "eth:$dev:::$ip"
                    ;;
                *)
                    echo "none::::"
                    ;;
            esac
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const [kind, device, ssid, signal, ip] = text.trim().split(":")
                root.kind = kind
                root.device = device
                root.ssid = ssid
                root.signal = parseInt(signal) || 0
                root.ip = ip
            }
        }
    }

    Process {
        id: scanProc
        command: ["sh", "-c",
            "nmcli -t -f active,ssid,signal,security dev wifi list --rescan yes 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set()
                const rows = text.trim().split("\n")
                    .map(line => {
                        const [active, ssid, signal, security] = line.split(":")
                        return { active: active === "yes", ssid, signal: parseInt(signal) || 0, security }
                    })
                    .filter(r => r.ssid && !seen.has(r.ssid) && seen.add(r.ssid))
                    .sort((a, b) => b.signal - a.signal)
                    .slice(0, 10)
                root.scanResults = rows
                root.scanning = false
            }
        }
    }

    Process {
        id: connectProc
        property string targetSsid: ""
        stdout: StdioCollector { id: connectStdout }
        stderr: StdioCollector { id: connectStderr }
        onExited: (exitCode) => {
            root.connectStatus = exitCode === 0
                ? "connected to " + connectProc.targetSsid
                : "failed: " + (connectStderr.text.trim() || connectStdout.text.trim() || "unknown error")
            root.refresh()
            root.scan()
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
