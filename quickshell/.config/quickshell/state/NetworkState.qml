// Shared network status, polled once here (not per-screen) and read by both
// Bar.qml's icon and popups/NetworkMenu.qml — both pull it in via
// `import "./state"` / `import "../state"`; no IPC needed since it's the
// same QML singleton either way.
//
// Tracks every managed ethernet/wifi/wwan device, not just one: "primary"
// is whichever connected device holds the lowest-metric IPv4 default route,
// i.e. the one traffic actually leaves through. The old version took the
// first line of `nmcli con show --active`, which is ordered by activation,
// not routing — with both ethernet and wifi up it could show wifi while
// everything went out over ethernet.
//
// Refreshes are event-driven off `nmcli monitor` (debounced), with a slow
// timer on top only so wifi signal strength doesn't go stale — monitor
// doesn't report signal changes.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    // Must stay above NetworkManager's VPN default (50): a physical link at
    // or below it would beat a full-tunnel VPN's default route and leak
    // traffic around the tunnel. Below ethernet's default (100) so any
    // device type can be promoted over any other.
    readonly property int primaryMetric: 75

    property var devices: []      // [{device, type, state, connected, connection, uuid, ip, gateway, metric, primary, signal}]
    property var vpns: []         // [{name, uuid, type, active}]
    property var wifiNetworks: [] // [{ssid, signal, security, active, known}]
    property var savedSsids: ({}) // ssid -> [uuid, ...]
    property bool wifiEnabled: true

    readonly property var primary: devices.find(d => d.primary) || devices.find(d => d.connected) || null
    readonly property var wifiDevice: devices.find(d => d.type === "wifi") || null
    readonly property bool vpnActive: vpns.some(v => v.active)

    // Kept for Bar.qml's color logic — all derived from `primary`.
    readonly property string kind: !primary ? "none" : primary.type === "wifi" ? "wifi" : "eth"
    readonly property int signal: primary && primary.type === "wifi" ? primary.signal : 0

    property bool scanning: false
    property string actionStatus: ""
    property bool busy: actionProc.running

    function refresh() {
        if (statusProc.running) pendingRefresh = true
        else statusProc.running = true
    }
    property bool pendingRefresh: false

    function scan() {
        if (scanProc.running) return
        scanning = true
        scanProc.running = true
    }

    function icon(dev) {
        if (!dev) return wifiEnabled ? "\u{f092d}" : "\u{f05aa}"
        if (dev.type === "wifi") {
            if (!dev.connected) return wifiEnabled ? "\u{f092e}" : "\u{f05aa}"
            return wifiGlyph(dev.signal)
        }
        if (dev.type === "wwan") return "\u{f0a60}"
        return dev.connected ? "\u{f0200}" : "\u{f0319}"
    }

    function wifiGlyph(pct) {
        if (pct >= 75) return "\u{f0928}"
        if (pct >= 50) return "\u{f0925}"
        if (pct >= 25) return "\u{f0922}"
        return "\u{f091f}"
    }

    // nmcli -t escapes ":" and "\" inside values (SSIDs can contain both),
    // so a plain split(":") mangles them.
    function splitTerse(line) {
        const out = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
            if (c === ":") { out.push(cur); cur = ""; continue }
            cur += c
        }
        out.push(cur)
        return out
    }

    // `input` (optional) is written to the command's stdin — how secrets
    // reach it without showing up in argv.
    function run(label, cmd, input) {
        if (actionProc.running) {
            actionStatus = "busy — wait for the previous action"
            return
        }
        actionStatus = label + "…"
        actionProc.label = label
        actionProc.input = input || ""
        actionProc.stdinEnabled = actionProc.input !== ""
        actionProc.command = cmd
        actionProc.running = true
    }

    function toggleDevice(dev) {
        if (dev.connected) run("disconnecting " + dev.device, ["nmcli", "device", "disconnect", dev.device])
        else run("connecting " + dev.device, ["nmcli", "device", "connect", dev.device])
    }

    function setWifiEnabled(on) {
        run(on ? "enabling wi-fi" : "disabling wi-fi", ["nmcli", "radio", "wifi", on ? "on" : "off"])
    }

    // Pins `dev`'s profile to primaryMetric, and resets any other connected
    // profile that's explicitly at or below it back to its type default
    // (-1). Profiles with a higher explicit metric are left alone. `device
    // reapply` swaps the routes live without dropping the link; `con up` is
    // only the fallback if reapply refuses.
    function setPrimary(dev) {
        const others = devices.filter(d => d.connected && d.uuid && d.device !== dev.device)
            .flatMap(d => [d.uuid, d.device])
        run("making " + dev.device + " primary", ["sh", "-c", `
            m=$1; uuid=$2; dev=$3; shift 3
            apply() { nmcli device reapply "$2" >/dev/null 2>&1 || nmcli connection up uuid "$1" >/dev/null; }
            while [ $# -ge 2 ]; do
                cur=$(nmcli -g ipv4.route-metric connection show uuid "$1")
                if [ "$cur" -ge 0 ] 2>/dev/null && [ "$cur" -le "$m" ]; then
                    nmcli connection modify uuid "$1" ipv4.route-metric -1 ipv6.route-metric -1 && apply "$1" "$2"
                fi
                shift 2
            done
            nmcli connection modify uuid "$uuid" ipv4.route-metric "$m" ipv6.route-metric "$m" || exit 1
            apply "$uuid" "$dev"
        `, "sh", String(primaryMetric), dev.uuid, dev.device].concat(others))
    }

    // Saved or open networks: activate as-is. With a password: set it on
    // the saved profile (or a new one) through `nmcli connection edit`'s
    // stdin rather than `nmcli ... password X` — argv is world-readable in
    // /proc/<pid>/cmdline for as long as nmcli runs. The password arrives
    // on the script's stdin, and printf is a shell builtin (never its own
    // process). A profile created here is deleted
    // again if activation fails, like `nmcli device wifi connect` does.
    function connectWifi(net, password) {
        const uuids = savedSsids[net.ssid] || []
        const ifname = wifiDevice ? wifiDevice.device : ""
        if (!password) {
            if (uuids.length) run("connecting to " + net.ssid, ["nmcli", "connection", "up", "uuid", uuids[0]].concat(ifname ? ["ifname", ifname] : []))
            else run("connecting to " + net.ssid, ["nmcli", "device", "wifi", "connect", net.ssid].concat(ifname ? ["ifname", ifname] : []))
            return
        }
        // WPA3-only networks need SAE; mixed WPA2/WPA3 accept plain PSK.
        const keyMgmt = /WPA3/.test(net.security) && !/WPA[12]/.test(net.security) ? "sae" : "wpa-psk"
        run("connecting to " + net.ssid, ["sh", "-c", `
            IFS= read -r psk
            uuid=$1; ssid=$2; ifname=$3; km=$4; created=
            if [ -z "$uuid" ]; then
                out=$(nmcli connection add type wifi con-name "$ssid" ssid "$ssid" wifi-sec.key-mgmt "$km") || exit 1
                uuid=$(printf '%s' "$out" | sed -n 's/.*(\\([0-9a-f-]*\\)).*/\\1/p')
                [ -n "$uuid" ] || { echo "could not create profile" >&2; exit 1; }
                created=1
            fi
            printf 'set 802-11-wireless-security.psk %s\\nsave persistent\\nquit\\n' "$psk" \\
                | nmcli connection edit uuid "$uuid" >/dev/null 2>&1
            if [ -n "$ifname" ]; then nmcli connection up uuid "$uuid" ifname "$ifname"
            else nmcli connection up uuid "$uuid"; fi && exit 0
            [ -n "$created" ] && nmcli connection delete uuid "$uuid" >/dev/null 2>&1
            exit 1
        `, "sh", uuids[0] || "", net.ssid, ifname, keyMgmt], password)
    }

    function forgetWifi(ssid) {
        // Array.from: values read back out of a `var` property are Qt
        // sequence wrappers, which lack flatMap and friends.
        const uuids = Array.from(savedSsids[ssid] || [])
        if (uuids.length === 0) return
        run("forgetting " + ssid, ["nmcli", "connection", "delete"].concat(uuids.flatMap(u => ["uuid", u])))
    }

    function toggleVpn(vpn) {
        run((vpn.active ? "stopping " : "starting ") + vpn.name,
            ["nmcli", "connection", vpn.active ? "down" : "up", "uuid", vpn.uuid])
    }

    function openEditor() {
        Quickshell.execDetached(["nm-connection-editor"])
    }

    Process {
        id: statusProc
        command: ["sh", "-c", `
            echo '#DEV'; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION,CON-UUID device status 2>/dev/null
            echo '#ROUTE'; ip -4 route show default 2>/dev/null
            echo '#ADDR'; ip -4 -o addr show 2>/dev/null
            echo '#RADIO'; nmcli -t -f WIFI radio 2>/dev/null
            echo '#WIFI'; nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null
            echo '#CON'; nmcli -t -f NAME,UUID,TYPE,ACTIVE connection show 2>/dev/null
        `]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
        }
        onExited: {
            if (root.pendingRefresh) {
                root.pendingRefresh = false
                statusProc.running = true
            }
        }
    }

    // Polls return fresh arrays even when nothing changed; reassigning them
    // anyway rebuilds every Repeater delegate reading them (hover state and
    // all) on each tick.
    function assignIfChanged(name, value) {
        if (JSON.stringify(root[name]) !== JSON.stringify(value)) root[name] = value
    }

    function parseStatus(text) {
        const sections = {}
        let cur = null
        for (const line of text.split("\n")) {
            if (line.startsWith("#")) { cur = sections[line.slice(1)] = []; continue }
            if (cur && line.length) cur.push(line)
        }

        const routes = {}
        for (const line of sections.ROUTE || []) {
            const dev = (line.match(/\bdev (\S+)/) || [])[1]
            if (!dev) continue
            const metric = parseInt((line.match(/\bmetric (\d+)/) || [])[1]) || 0
            if (routes[dev] && routes[dev].metric <= metric) continue
            routes[dev] = { gateway: (line.match(/\bvia (\S+)/) || [])[1] || "", metric }
        }

        const addrs = {}
        for (const line of sections.ADDR || []) {
            const m = line.match(/^\d+:\s+(\S+)\s+inet\s+([\d.]+)/)
            if (m && !addrs[m[1]]) addrs[m[1]] = m[2]
        }

        wifiEnabled = (sections.RADIO || [])[0] === "enabled"

        const nets = {}
        let activeSignal = 0
        for (const line of sections.WIFI || []) {
            const [active, sig, security, ssid] = splitTerse(line)
            const signal = parseInt(sig) || 0
            if (active === "yes") activeSignal = Math.max(activeSignal, signal)
            if (!ssid) continue
            const prev = nets[ssid]
            nets[ssid] = {
                ssid,
                signal: Math.max(signal, prev ? prev.signal : 0),
                security: security && security !== "--" ? security : "",
                active: active === "yes" || (prev ? prev.active : false),
                known: !!savedSsids[ssid],
            }
        }
        // Signal in 4 bands (the same tiers as the icon), then by name: an
        // exact-signal sort reshuffles the whole list on every poll, which
        // makes a crowded office list impossible to read.
        const bandRank = (n) => n.signal >= 75 ? 3 : n.signal >= 50 ? 2 : n.signal >= 25 ? 1 : 0
        assignIfChanged("wifiNetworks", Object.values(nets)
            .sort((a, b) => (b.active - a.active) || (b.known - a.known)
                || (bandRank(b) - bandRank(a)) || a.ssid.localeCompare(b.ssid)))

        const typeMap = { ethernet: "ethernet", wifi: "wifi", gsm: "wwan", cdma: "wwan" }
        const devs = []
        for (const line of sections.DEV || []) {
            const [device, rawType, state, connection, uuid] = splitTerse(line)
            const type = typeMap[rawType]
            if (!type || state === "unmanaged") continue
            const connected = state === "connected"
            const route = routes[device]
            devs.push({
                device, type, state, connected,
                connection: connected || state.startsWith("connecting") ? connection : "",
                uuid: connected ? uuid : "",
                ip: addrs[device] || "",
                gateway: route ? route.gateway : "",
                metric: route ? route.metric : -1,
                primary: false,
                signal: type === "wifi" && connected ? activeSignal : 0,
            })
        }
        const routed = devs.filter(d => d.connected && d.metric >= 0).sort((a, b) => a.metric - b.metric)
        if (routed.length) routed[0].primary = true
        const order = { ethernet: 0, wifi: 1, wwan: 2 }
        devs.sort((a, b) => (b.connected - a.connected) || (order[a.type] - order[b.type]) || a.device.localeCompare(b.device))
        assignIfChanged("devices", devs)

        const vpnTypes = ["vpn", "wireguard"]
        assignIfChanged("vpns", (sections.CON || []).map(line => splitTerse(line))
            .filter(([, , type]) => vpnTypes.includes(type))
            .map(([name, uuid, type, active]) => ({ name, uuid, type, active: active === "yes" })))
    }

    // Forced rescan (blocks until the radio finishes, a few seconds), plus
    // the SSID behind each saved wifi profile — profile names don't have to
    // match their SSID, so "known"/[forget] can't just go by name. Only run
    // when the popup opens or on [rescan], not on every poll.
    Process {
        id: scanProc
        command: ["sh", "-c", `
            nmcli device wifi rescan 2>/dev/null
            sleep 3
            nmcli -t -f UUID,TYPE connection show 2>/dev/null | while IFS=: read -r uuid type; do
                [ "$type" = 802-11-wireless ] || continue
                printf '%s:%s\\n' "$uuid" "$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null)"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":")
                    if (i < 0) continue
                    const ssid = line.slice(i + 1)
                    if (!ssid) continue
                    ;(saved[ssid] = saved[ssid] || []).push(line.slice(0, i))
                }
                root.savedSsids = saved
            }
        }
        onExited: {
            root.scanning = false
            root.refresh()
        }
    }

    Process {
        id: actionProc
        property string label: ""
        property string input: ""
        onStarted: if (input !== "") { write(input + "\n"); stdinEnabled = false }
        stdout: StdioCollector { id: actionStdout }
        stderr: StdioCollector { id: actionStderr }
        onExited: (exitCode) => {
            const err = (actionStderr.text.trim() || actionStdout.text.trim()).split("\n").pop()
            root.actionStatus = exitCode === 0 ? "" : "failed: " + (err || actionProc.label)
            root.refresh()
            if (actionProc.label.startsWith("forgetting") || actionProc.label.startsWith("connecting to")) root.scan()
        }
    }

    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: debounce.restart() }
        // nmcli monitor exits if NetworkManager restarts — pick it back up.
        onExited: respawn.start()
    }

    Timer { id: respawn; interval: 5000; onTriggered: monitorProc.running = true }
    Timer { id: debounce; interval: 400; onTriggered: root.refresh() }

    Timer {
        interval: PopupState.isOpen("network") ? 3000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: scan()
}
