// ZeroTier as a VPN provider in the network popup (see
// components/VpnProvider.qml). There's no single tunnel to switch on and
// off — the node is online while zerotier-one runs, and joins networks — so
// no [connect]; ZerotierDetail joins/leaves networks instead. `zerotier-cli
// -j` is polled; it needs ~/.zeroTierOneAuthToken, which setup.sh copies
// from the service's authtoken.secret.
import Quickshell
import Quickshell.Io
import QtQuick
import "../../components"

VpnProvider {
    id: root

    name: "ZeroTier"
    detailComponent: Qt.resolvedUrl("ZerotierDetail.qml")
    interfaces: ["zt"]
    canToggle: false

    property bool online: false
    property string address: ""       // this node's 10-digit id
    // [{id, name, status, ips, device}]; status OK / REQUESTING_CONFIGURATION /
    // ACCESS_DENIED / NOT_FOUND / PORT_ERROR
    property var networks: []
    readonly property var up: networks.filter(n => n.status === "OK")

    active: online && up.length > 0
    warning: networks.some(n => n.status === "ACCESS_DENIED" || n.status === "NOT_FOUND" || n.status === "PORT_ERROR")
    status: !online ? "offline"
        : networks.length === 0 ? "online · no networks"
        : up.length + "/" + networks.length + " networks up"
    detail: up.map(n => (n.name || n.id) + (n.ips.length ? " " + n.ips[0] : "")).join(" · ")

    function join(id) { run("joining " + id, ["zerotier-cli", "join", id]) }
    function leave(id) { run("leaving " + id, ["zerotier-cli", "leave", id]) }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    // Two JSON documents, info then listnetworks, split by a marker line.
    function parse(text) {
        const parts = text.split("\n#NETWORKS\n")
        let info, nets
        try {
            info = JSON.parse(parts[0])
            nets = JSON.parse(parts[1] || "[]")
        } catch (e) {
            available = false
            return
        }
        available = true
        online = !!info.online
        address = info.address || ""
        const list = nets.map(n => ({
            id: n.nwid || n.id || "",
            name: n.name || "",
            status: n.status || "",
            ips: (n.assignedAddresses || []).map(a => a.replace(/\/\d+$/, "")),
            device: n.portDeviceName || "",
        }))
        if (JSON.stringify(list) !== JSON.stringify(networks)) networks = list
    }

    Process {
        id: statusProc
        command: ["sh", "-c", "command -v zerotier-cli >/dev/null && zerotier-cli -j info && echo '#NETWORKS' && zerotier-cli -j listnetworks"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
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
