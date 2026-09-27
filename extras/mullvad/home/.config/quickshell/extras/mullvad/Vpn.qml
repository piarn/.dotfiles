// Mullvad as a VPN provider in the network popup (see
// components/VpnProvider.qml). Tunnel state is event-driven off `mullvad
// status --json listen` (one JSON line per change, the current state
// first); the settings MullvadDetail shows (relay location, lockdown,
// auto-connect, account expiry) only change through it or the CLI, so
// they're re-read on popup open and after every action instead of polled.
import Quickshell
import Quickshell.Io
import QtQuick
import "../../components"

VpnProvider {
    id: root

    name: "Mullvad"
    detailComponent: Qt.resolvedUrl("MullvadDetail.qml")
    interfaces: ["wg0-mullvad"]

    // disconnected / connecting / connected / disconnecting / error
    property string tunnel: "disconnected"
    property bool lockedDown: false  // blocking traffic while disconnected
    property string country: ""
    property string city: ""
    property string hostname: ""     // relay, while connected
    property string ip: ""

    property string relayLocation: "" // "country pl", "city se got", "any", ...
    property bool lockdown: false
    property bool autoConnect: false
    property var expires: null        // Date
    readonly property int daysLeft: expires ? Math.floor((expires - Date.now()) / 86400000) : -1

    // [{name, code, cities: [{name, code}]}], read on first expand
    property var countries: []

    active: tunnel === "connected"
    busy: tunnel === "connecting" || tunnel === "disconnecting"
    warning: tunnel === "error" || lockedDown
    status: {
        switch (tunnel) {
            case "connected": return "connected"
            case "connecting": return "connecting…"
            case "disconnecting": return "disconnecting…"
            case "error": return "error — traffic blocked"
            default: return lockedDown ? "off — traffic blocked" : "disconnected"
        }
    }
    detail: [[country, city].filter(s => s).join(", "), hostname, ip].filter(s => s).join(" · ")

    function toggle() {
        if (active || tunnel === "connecting") run("disconnecting", ["mullvad", "disconnect"])
        else run("connecting", ["mullvad", "connect"])
    }
    function reconnect() { run("reconnecting", ["mullvad", "reconnect"]) }
    function setLockdown(on) { run("lockdown " + (on ? "on" : "off"), ["mullvad", "lockdown-mode", "set", on ? "on" : "off"]) }
    function setAutoConnect(on) { run("auto-connect " + (on ? "on" : "off"), ["mullvad", "auto-connect", "set", on ? "on" : "off"]) }
    // `city` optional; "any" for country lets the daemon pick anywhere.
    function setLocation(country, city) {
        run("switching to " + (city ? country + " " + city : country),
            ["mullvad", "relay", "set", "location", country].concat(city ? [city] : []))
    }

    function refresh() {
        if (available && !settingsProc.running) settingsProc.running = true
    }

    function loadRelays() {
        if (available && !countries.length && !relayProc.running) relayProc.running = true
    }

    function parseStatus(line) {
        let s
        try { s = JSON.parse(line) } catch (e) { return }
        const d = s.details || {}
        const loc = d.location || {}
        tunnel = s.state || "disconnected"
        lockedDown = !!d.locked_down
        country = loc.country || ""
        city = loc.city || ""
        hostname = loc.hostname || ""
        ip = loc.ipv4 || loc.ipv6 || ""
    }

    // Plain-text `get` output; there's no --json for these.
    function parseSettings(text) {
        const field = (re) => { const m = text.match(re); return m ? m[1].trim() : "" }
        relayLocation = field(/^\s*Location:\s*(.+)$/m)
        lockdown = field(/^Block traffic when the VPN is disconnected:\s*(\S+)/m) === "on"
        autoConnect = field(/^Autoconnect:\s*(\S+)/m) === "on"
        const exp = field(/^Expires at:\s*(.+)$/m)
        // "2026-10-08 19:23:59 +03:00" → ISO so Date parses it everywhere
        expires = exp ? new Date(exp.replace(/^(\S+) (\S+) ([+-]\d\d:\d\d)$/, "$1T$2$3")) : null
    }

    function parseRelays(text) {
        const out = []
        for (const line of text.split("\n")) {
            let m
            if ((m = line.match(/^(\S.*) \(([a-z]{2})\)$/)))
                out.push({ name: m[1], code: m[2], cities: [] })
            else if ((m = line.match(/^\t(\S.*) \(([a-z]{3})\) @/)) && out.length)
                out[out.length - 1].cities.push({ name: m[1], code: m[2] })
        }
        countries = out
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v mullvad"]
        onExited: (code) => root.available = code === 0
    }

    // Exits when the daemon restarts or isn't up yet; retry until it's back.
    Process {
        id: listenProc
        running: root.available
        command: ["mullvad", "status", "--json", "listen"]
        stdout: SplitParser {
            onRead: (line) => root.parseStatus(line)
        }
        onExited: {
            root.tunnel = "disconnected"
            relisten.start()
        }
    }
    Timer {
        id: relisten
        interval: 5000
        onTriggered: listenProc.running = root.available
    }

    Process {
        id: settingsProc
        command: ["sh", "-c", "mullvad relay get; mullvad lockdown-mode get; mullvad auto-connect get; mullvad account get"]
        stdout: StdioCollector {
            onStreamFinished: root.parseSettings(text)
        }
    }

    Process {
        id: relayProc
        command: ["mullvad", "relay", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parseRelays(text)
        }
    }

    onAvailableChanged: refresh()
}
