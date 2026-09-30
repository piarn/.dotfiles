// Base for a VPN client that isn't a NetworkManager profile (Mullvad,
// Tailscale, NetBird, ...). An opt-in extra ships one as
// extras/<name>/Vpn.qml (see state/ExtrasState.qml); the network tab's vpn
// section lists every `available` one next to the NM profiles.
//
//   VpnProvider {
//       name: "Tailscale"
//       available: ...            // CLI installed + daemon reachable
//       active: ...               // tunnel up
//       detail: "100.64.0.1 · 3/5 peers"
//       detailComponent: Qt.resolvedUrl("TailscaleDetail.qml")  // optional
//       function toggle() { run(active ? "stopping" : "starting", ["tailscale", active ? "down" : "up"]) }
//       function refresh() { ... }  // popup opened / after run() finishes
//   }
//
// detailComponent is an Item shown under the row when it's expanded; it
// gets `provider` (this object) and `width` set.
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property string name: ""
    property bool available: false
    property bool active: false
    property bool busy: false        // connecting/disconnecting
    property bool warning: false     // up but degraded, or blocking traffic
    property string status: active ? "connected" : "disconnected"
    property string detail: ""
    property url detailComponent: ""
    // Prefixes of the NM connection names this client's tunnel shows up
    // under (e.g. wg0-mullvad, "ProtonVPN CH#242") — hidden from the NM
    // profile list so it isn't listed twice.
    property var interfaces: []
    // false: no [connect]/[disconnect] (e.g. ZeroTier, which joins networks
    // instead); everything happens in detailComponent.
    property bool canToggle: true
    // Set while a text field in detailComponent is focused, so the popup
    // takes the keyboard exclusively (see island/Island.qml).
    property bool wantsKeyboard: false

    property string actionStatus: ""
    readonly property bool running: actionProc.running

    function toggle() {}
    function refresh() {}

    // Runs one CLI action at a time; failures land in actionStatus.
    function run(label, cmd) {
        if (actionProc.running) return
        actionStatus = label + "…"
        actionProc.label = label
        actionProc.command = cmd
        actionProc.running = true
    }

    Process {
        id: actionProc
        property string label: ""
        stdout: StdioCollector { id: actionStdout }
        stderr: StdioCollector { id: actionStderr }
        onExited: (exitCode) => {
            const err = (actionStderr.text.trim() || actionStdout.text.trim()).split("\n").pop()
            root.actionStatus = exitCode === 0 ? "" : "failed: " + (err || actionProc.label)
            root.refresh()
        }
    }
}
