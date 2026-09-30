// Proton VPN (the official open-source CLI, proton-vpn-cli) as a VPN
// provider in the network tab (see components/VpnProvider.qml). `protonvpn
// status` is plain text and a Python start-up per call, so it's polled
// slowly; sign-in state and the kill switch come from `protonvpn config
// list` (which fails while signed out), read when the tab opens and after actions.
// The CLI brings its tunnel up as a NetworkManager connection named after
// the server ("ProtonVPN CH#242"), hidden from the NM rows via `interfaces`.
import Quickshell
import Quickshell.Io
import QtQuick
import "../../components"

VpnProvider {
    id: root

    name: "Proton VPN"
    detailComponent: Qt.resolvedUrl("ProtonDetail.qml")
    interfaces: ["ProtonVPN", "proton"]

    property bool connected: false
    property string server: ""        // "CH#242"
    property string location: ""      // "Zurich, Switzerland"
    property string load: ""
    property string protocol: ""

    property bool signedIn: true      // assume so until config list says otherwise
    property string killSwitch: ""    // off / standard

    // [{name, code}], read on first expand
    property var countries: []

    active: connected
    warning: !signedIn
    status: !signedIn ? "signed out" : connected ? "connected" : "disconnected"
    detail: connected ? [server, location, protocol, load ? "load " + load : ""].filter(s => s).join(" · ") : ""

    // Sign-in prompts for the password (and 2FA) on a terminal.
    function signIn() {
        Quickshell.execDetached(["kitty", "--title", "Proton VPN sign in", "sh", "-c",
            "printf 'Proton account: '; read -r u && protonvpn signin \"$u\"; printf '\\n[enter to close] '; read -r _"])
    }

    function toggle() {
        if (!signedIn) signIn()
        else if (active) run("disconnecting", ["protonvpn", "disconnect"])
        else run("connecting to the fastest server", ["protonvpn", "connect"])
    }
    function connectCountry(code) {
        run("connecting to " + code, ["protonvpn", "connect", "--country", code])
    }
    // Only while disconnected — the CLI refuses otherwise.
    function setKillSwitch(mode) {
        run("kill switch " + mode, ["protonvpn", "config", "set", "kill-switch", mode])
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
        if (!configProc.running) configProc.running = true
    }

    function loadCountries() {
        if (!countries.length && !countryProc.running) countryProc.running = true
    }

    function parseStatus(text) {
        const field = (re) => { const m = text.match(re); return m ? m[1].trim() : "" }
        const st = field(/^Status:\s*(\S+)/m)
        available = st !== ""
        connected = st === "Connected"
        const srv = text.match(/^Server:\s*(\S+)(?: in (.+))?$/m)
        server = srv ? srv[1] : ""
        location = srv && srv[2] ? srv[2].trim() : ""
        load = field(/^Load:\s*(.+)$/m)
        protocol = field(/^Protocol:\s*(.+)$/m)
    }

    Process {
        id: statusProc
        command: ["sh", "-c", "command -v protonvpn >/dev/null && protonvpn status 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
        }
    }

    // `config list` is a table of "setting   value" rows; while signed out
    // it fails with a "sign in" hint instead.
    Process {
        id: configProc
        command: ["sh", "-c", "command -v protonvpn >/dev/null && protonvpn config list 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ks = text.match(/^kill-switch\s+(\S+)/m)
                if (ks) {
                    root.signedIn = true
                    root.killSwitch = ks[1]
                } else if (/sign ?in/i.test(text)) {
                    root.signedIn = false
                }
            }
        }
    }

    // "simple" tabulate table: header, dashes, then "Country name   CH".
    Process {
        id: countryProc
        command: ["protonvpn", "countries", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\S.*?)\s{2,}([A-Z]{2})\s*$/)
                    if (m && m[1] !== "Country") out.push({ name: m[1], code: m[2] })
                }
                root.countries = out
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!statusProc.running) statusProc.running = true
    }

    Component.onCompleted: if (!configProc.running) configProc.running = true
}
