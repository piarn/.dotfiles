// Bluetooth, backed by the native Quickshell.Bluetooth module (bluez over
// D-Bus) — fully reactive, no polling. This used to shell out to
// bluetoothctl every 5s (plus one `bluetoothctl info` per known device)
// because Bluetooth.adapters never populated under Quickshell 0.2.1. On
// 0.3.1 it does, but only once something *binds* to it: the module starts
// tracking bluez lazily, so an imperative read right at startup still sees
// null. Everything here is a binding for that reason.
pragma Singleton
import Quickshell.Bluetooth
import QtQuick

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false

    // Connected, then paired, then discovered-with-a-name. Unnamed
    // discoveries (bluez aliases them to their address) are noise.
    readonly property var devices: {
        if (!adapter) return []
        return adapter.devices.values
            .filter(d => d.paired || d.connected || d.deviceName)
            .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    }
    readonly property var connectedDevices: devices.filter(d => d.connected)

    function togglePower() {
        if (adapter) adapter.enabled = !adapter.enabled
    }

    function scan() {
        if (!adapter || !adapter.enabled) return
        adapter.discovering = true
        scanStop.restart()
    }

    // Trusted so it can reconnect on its own later; pairing itself goes
    // through the agent sway starts (~/.local/bin/bluetooth-agent).
    function pair(device) {
        device.trusted = true
        device.pair()
    }

    function busy(device) {
        return device.pairing || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting
    }

    function stateText(device) {
        if (device.pairing) return "pairing…"
        if (device.state === BluetoothDeviceState.Connecting) return "connecting…"
        if (device.state === BluetoothDeviceState.Disconnecting) return "disconnecting…"
        return ""
    }

    function icon(device) {
        const i = device.icon || ""
        if (i.startsWith("audio")) return "\u{f02cb}"
        if (i === "input-mouse") return "\u{f037d}"
        if (i === "input-keyboard") return "\u{f030c}"
        if (i === "input-gaming") return "\u{f0297}"
        if (i === "phone") return "\u{f011c}"
        return "\u{f00af}"
    }

    Timer {
        id: scanStop
        interval: 15000
        onTriggered: if (root.adapter) root.adapter.discovering = false
    }
}
