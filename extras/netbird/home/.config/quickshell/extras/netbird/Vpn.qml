// NetBird as a VPN provider in the network tab (see
// components/VpnProvider.qml). The CLI has no event stream, so `netbird
// status --json` is polled; its daemonStatus is the tunnel state
// (Idle / Connecting / Connected / NeedsLogin / LoginFailed / SessionExpired).
// "Connected" only means the daemon is up — management and signal being
// unreachable still leaves peers unreachable, so that's flagged as a warning.
import Quickshell
import Quickshell.Io
import QtQuick
import "../../components"

VpnProvider {
    id: root

    name: "NetBird"
    detailComponent: Qt.resolvedUrl("NetbirdDetail.qml")
    interfaces: ["wt0"]

    property string daemon: ""        // daemonStatus, "" while unknown
    property bool management: false
    property string managementError: ""
    property string ip: ""
    property string fqdn: ""
    property var peers: []            // [{name, ip, status}], connected first
    property int peersConnected: 0
    property var expires: null        // Date, SSO session expiry

    readonly property bool needsLogin: ["NeedsLogin", "LoginFailed", "SessionExpired"].includes(daemon)

    active: daemon === "Connected"
    busy: daemon === "Connecting"
    warning: needsLogin || (active && !management)
    status: {
        if (active) return management ? "connected" : "connected — management unreachable"
        if (busy) return "connecting…"
        if (daemon === "SessionExpired") return "session expired"
        if (needsLogin) return "needs login"
        return "disconnected"
    }
    detail: active ? [fqdn.split(".")[0], ip, peersConnected + "/" + peers.length + " peers"].filter(s => s).join(" · ") : ""

    // `up` opens the SSO page in the browser when a login is needed, and
    // doesn't return until it's done.
    function toggle() {
        if (active || busy) run("disconnecting", ["netbird", "down"])
        else run(needsLogin ? "logging in (see browser)" : "connecting", ["netbird", "up"])
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function parseStatus(text) {
        let s
        try { s = JSON.parse(text) } catch (e) {
            // Daemon down/unreachable: plain-text error, no JSON.
            available = false
            return
        }
        available = true
        daemon = s.daemonStatus || ""
        management = !!(s.management && s.management.connected)
        managementError = s.management && s.management.error || ""
        ip = (s.netbirdIp || "").replace(/\/\d+$/, "")
        fqdn = s.fqdn || ""
        const list = ((s.peers && s.peers.details) || []).map(p => ({
            name: (p.fqdn || "").split(".")[0], ip: p.netbirdIp || "", status: p.status || "",
        }))
        list.sort((a, b) => ((b.status === "Connected") - (a.status === "Connected")) || a.name.localeCompare(b.name))
        if (JSON.stringify(list) !== JSON.stringify(peers)) peers = list
        peersConnected = list.filter(p => p.status === "Connected").length
        // absent/zero ("0001-01-01T00:00:00Z") while down or with setup keys
        const exp = new Date(s.sessionExpiresAt || "")
        expires = exp.getFullYear() > 2000 ? exp : null
    }

    Process {
        id: statusProc
        command: ["sh", "-c", "command -v netbird >/dev/null && netbird status --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
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
