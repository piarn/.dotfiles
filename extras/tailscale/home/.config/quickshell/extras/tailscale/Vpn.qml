// Tailscale as a VPN provider in the network tab (see
// components/VpnProvider.qml). `tailscale status --json` is polled (there's
// no stable event stream outside `debug watch-ipn`); BackendState is the
// tunnel state (NoState / NeedsLogin / NeedsMachineAuth / Stopped /
// Starting / Running). up/down/set need no sudo because setup.sh makes the
// user tailscale's operator.
import Quickshell
import Quickshell.Io
import QtQuick
import "../../components"

VpnProvider {
    id: root

    name: "Tailscale"
    detailComponent: Qt.resolvedUrl("TailscaleDetail.qml")
    interfaces: ["tailscale0"]

    property string backend: ""
    property string authUrl: ""
    property string ip: ""
    property string host: ""
    property string tailnet: ""
    property var peers: []           // [{name, ip, online, os, exitNodeOption, exitNode}]
    readonly property var exitNodes: peers.filter(p => p.exitNodeOption)
    readonly property var exitNode: peers.find(p => p.exitNode) || null

    active: backend === "Running"
    busy: backend === "Starting"
    warning: backend === "NeedsLogin" || backend === "NeedsMachineAuth"
    status: {
        switch (backend) {
            case "Running": return exitNode ? "connected via " + exitNode.name : "connected"
            case "Starting": return "connecting…"
            case "NeedsLogin": return "needs login"
            case "NeedsMachineAuth": return "waiting for admin approval"
            default: return "disconnected"
        }
    }
    detail: active ? [host, ip, tailnet, peers.filter(p => p.online).length + "/" + peers.length + " online"].filter(s => s).join(" · ") : ""

    function toggle() {
        if (active || busy) run("disconnecting", ["tailscale", "down"])
        // `up` blocks until the login completes; AuthURL shows up in the
        // status meanwhile, and a second click opens it.
        else if (backend === "NeedsLogin" && authUrl) Qt.openUrlExternally(authUrl)
        else run(backend === "NeedsLogin" ? "logging in" : "connecting", ["tailscale", "up"])
    }

    // `ip` "" clears the exit node.
    function setExitNode(ip) {
        run(ip ? "switching exit node" : "clearing exit node", ["tailscale", "set", "--exit-node=" + ip])
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function parseStatus(text) {
        let s
        try { s = JSON.parse(text) } catch (e) {
            available = false
            return
        }
        available = true
        backend = s.BackendState || ""
        authUrl = s.AuthURL || ""
        const self = s.Self || {}
        ip = (self.TailscaleIPs || [])[0] || ""
        host = self.HostName || ""
        tailnet = (s.CurrentTailnet && s.CurrentTailnet.Name) || ""
        const list = Object.values(s.Peer || {}).map(p => ({
            name: p.HostName || (p.DNSName || "").split(".")[0],
            ip: (p.TailscaleIPs || [])[0] || "",
            online: !!p.Online,
            os: p.OS || "",
            exitNodeOption: !!p.ExitNodeOption,
            exitNode: !!p.ExitNode,
        }))
        list.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name))
        if (JSON.stringify(list) !== JSON.stringify(peers)) peers = list
    }

    Process {
        id: statusProc
        command: ["sh", "-c", "command -v tailscale >/dev/null && tailscale status --json 2>/dev/null"]
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
