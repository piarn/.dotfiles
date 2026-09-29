// The hub's "system" section: everything quick settings holds, as keyboard
// rows grouped under headers — network, bluetooth, audio, display, power,
// session. Rows only describe themselves (see HubRow for the kinds); the
// state singletons do the work, same calls quick settings makes.
//
// Live values (on, value, muted, subtitle, right, glyph) are functions the
// row evaluates itself, so `rows` only changes when the structure does (a
// device appears, a VPN profile is added). Otherwise every volume tick
// would rebuild the list, and a slider drag would lose its row mid-drag.
// Lists
// that can run long (wi-fi networks, bluetooth devices, audio devices)
// are pages you open with Enter.
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import "../../state"

QtObject {
    id: root

    readonly property string name: "system"
    readonly property string glyph: "\u{f0493}"

    // Asks the hub to open another popup (the network popup's password
    // prompt) and get out of the way.
    signal openPopup(string popup)

    // NM VPN profiles, minus the interfaces provider extras own (like
    // wg0-mullvad) — those are listed through their extra instead.
    readonly property var nmVpns: {
        const hidden = [].concat(...ExtrasState.vpns.map(v => Array.from(v.interfaces)))
        return NetworkState.vpns.filter(v => !hidden.some(h => v.name.startsWith(h)))
    }

    function networkRows() {
        return [
            { kind: "header", title: "network" },
            { kind: "toggle", group: "network", title: "wi-fi", glyph: "\u{f05a9}",
              aliases: "wifi wireless wlan",
              on: () => NetworkState.wifiEnabled,
              subtitle: () => {
                  const p = NetworkState.primary
                  return NetworkState.actionStatus || (p && p.connected
                      ? (p.type === "wifi" ? p.connection + " · " + p.signal + "%" : p.type) + " · " + (p.ip || "")
                      : "not connected")
              },
              run: () => NetworkState.setWifiEnabled(!NetworkState.wifiEnabled) },
            { kind: "page", group: "network", title: "wi-fi networks", glyph: "\u{f0928}",
              aliases: "wifi ssid connect scan",
              subtitle: () => NetworkState.wifiNetworks.length + " in range",
              enter: () => NetworkState.scan(),
              rows: () => wifiRows() },
        ].concat(nmVpns.map(v => ({
            kind: "toggle", group: "vpn", title: v.name, glyph: "\u{f0582}",
            aliases: "vpn " + v.type, subtitle: "vpn · " + v.type, on: () => v.active,
            run: () => NetworkState.toggleVpn(v),
        }))).concat(ExtrasState.vpns.filter(v => v.available).map(v => ({
            kind: "toggle", group: "vpn", title: v.name.toLowerCase(), glyph: "\u{f0582}",
            aliases: "vpn", subtitle: () => "vpn · " + (v.actionStatus || v.status), on: () => v.active,
            run: () => { if (v.canToggle && !v.running) v.toggle() },
        }))).concat([
            { kind: "action", group: "network", title: "network details", glyph: "\u{f0317}",
              aliases: "ip interfaces ethernet settings", subtitle: "the full network popup",
              run: () => root.openPopup("network") },
        ])
    }

    function wifiRows() {
        const nets = NetworkState.wifiNetworks
        if (!NetworkState.wifiEnabled) return [{ kind: "info", title: "wi-fi is off" }]
        if (!nets.length) return [{ kind: "info", title: NetworkState.scanning ? "scanning…" : "no networks found" }]
        return nets.map(n => ({
            kind: "choice", group: "wi-fi", title: n.ssid, glyph: NetworkState.wifiGlyph(n.signal),
            on: () => n.active,
            subtitle: [n.known ? "saved" : "", n.security || "open"].filter(s => s).join(" · "),
            right: n.signal + "%",
            // new secured networks need the password prompt
            run: () => {
                if (n.active) return
                if (n.known || !n.security) NetworkState.connectWifi(n)
                else root.openPopup("network")
            },
        }))
    }

    function bluetoothRows() {
        if (!BluetoothState.available) return []
        return [
            { kind: "header", title: "bluetooth" },
            { kind: "toggle", group: "bluetooth", title: "bluetooth", glyph: "\u{f00af}",
              aliases: "bt", on: () => BluetoothState.powered,
              subtitle: () => {
                  const conn = BluetoothState.connectedDevices
                  return conn.length ? conn.map(d => d.name).join(", ") : BluetoothState.powered ? "on" : "off"
              },
              run: () => BluetoothState.togglePower() },
            { kind: "page", group: "bluetooth", title: "devices", glyph: "\u{f02cb}",
              aliases: "bluetooth pair connect headphones",
              subtitle: () => BluetoothState.devices.length + " known or nearby",
              enter: () => BluetoothState.scan(),
              rows: () => deviceRows() },
        ]
    }

    function deviceRows() {
        if (!BluetoothState.powered) return [{ kind: "info", title: "bluetooth is off" }]
        const devs = BluetoothState.devices
        if (!devs.length) return [{ kind: "info", title: BluetoothState.scanning ? "scanning…" : "no devices" }]
        return devs.map(d => ({
            kind: "choice", group: "bluetooth", title: d.name, glyph: BluetoothState.icon(d),
            on: () => d.connected,
            subtitle: () => BluetoothState.stateText(d)
                || (d.connected ? "connected" + (d.batteryAvailable ? " · battery " + Math.round(d.battery * 100) + "%" : "")
                    : d.paired ? "paired · enter connects" : "new · enter pairs"),
            run: () => {
                if (BluetoothState.busy(d)) return
                if (d.connected) d.disconnect()
                else if (d.paired) d.connect()
                else BluetoothState.pair(d)
            },
        }))
    }

    function nodeRows(input) {
        const nodes = input ? VolumeState.sources : VolumeState.sinks
        if (!nodes.length) return [{ kind: "info", title: input ? "no input devices" : "no output devices" }]
        return nodes.map(n => ({
            kind: "choice", group: input ? "input" : "output",
            title: n.description || n.name, glyph: input ? "\u{f036c}" : "\u{f04c3}",
            on: () => n === (input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink),
            run: () => input ? VolumeState.setSource(n) : VolumeState.setSink(n),
        }))
    }

    function audioRows() {
        const sink = VolumeState.sinkAudio
        const src = VolumeState.sourceAudio
        const rows = [{ kind: "header", title: "audio" }]
        if (sink) rows.push({ kind: "level", group: "audio", title: "volume", glyph: () => VolumeState.speakerIcon(),
            aliases: "sound speaker output", value: () => sink.volume, muted: () => sink.muted,
            set: v => VolumeState.setVolume(false, v), adjust: d => VolumeState.adjustVolume(d),
            run: () => VolumeState.toggleMute(sink) })
        if (src) rows.push({ kind: "level", group: "audio", title: "microphone", glyph: () => VolumeState.micIcon(),
            aliases: "mic input", value: () => src.volume, muted: () => src.muted,
            set: v => VolumeState.setVolume(true, v), adjust: d => VolumeState.adjustMicVolume(d),
            run: () => VolumeState.toggleMute(src) })
        return rows.concat([
            { kind: "page", group: "audio", title: "output device", glyph: "\u{f04c3}",
              aliases: "speakers headphones sink", subtitle: () => Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.description : "", rows: () => nodeRows(false) },
            { kind: "page", group: "audio", title: "input device", glyph: "\u{f036c}",
              aliases: "microphone source", subtitle: () => Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.description : "", rows: () => nodeRows(true) },
        ])
    }

    function displayRows() {
        const rows = [{ kind: "header", title: "display" }]
        if (BrightnessState.available) rows.push({ kind: "level", group: "display", title: "brightness",
            glyph: "\u{f00e0}", aliases: "backlight screen",
            value: () => BrightnessState.value,
            set: v => BrightnessState.set(v), adjust: d => BrightnessState.adjust(d) })
        rows.push({ kind: "toggle", group: "display", title: "night light", glyph: "\u{f0594}",
            aliases: "wlsunset warm redshift blue light",
            on: () => NightLightState.active,
            subtitle: () => !NightLightState.available ? "install wlsunset"
                : NightLightState.active ? NightLightState.temperature + "K" : "off",
            run: () => { if (NightLightState.available) NightLightState.active = !NightLightState.active } })
        return rows.concat(RiceState.layouts.map(l => ({
            kind: "choice", group: "layout", title: l, glyph: "\u{f0379}",
            aliases: "layout screen monitor outputs",
            subtitle: "screen layout", on: () => l === RiceState.currentLayout,
            run: () => RiceState.applyLayout(l),
        })))
    }

    function powerRows() {
        const profiles = [
            { p: PowerProfile.PowerSaver, name: "power saver", glyph: "\u{f032a}" },
            { p: PowerProfile.Balanced, name: "balanced", glyph: "\u{f05d1}" },
        ]
        if (PowerProfiles.hasPerformanceProfile)
            profiles.push({ p: PowerProfile.Performance, name: "performance", glyph: "\u{f04c5}" })
        const rows = [{ kind: "header", title: "power" }].concat(profiles.map(x => ({
            kind: "choice", group: "power", title: x.name, glyph: x.glyph,
            aliases: "power profile mode", subtitle: "power profile",
            on: () => PowerProfiles.profile === x.p,
            run: () => PowerProfiles.profile = x.p,
        })))
        rows.push({ kind: "toggle", group: "power", title: "keep awake", glyph: "\u{f0176}",
            aliases: "caffeine idle inhibit",
            on: () => IdleState.inhibit, subtitle: () => IdleState.inhibit ? "no idle lock" : "off",
            run: () => IdleState.inhibit = !IdleState.inhibit })
        const dev = UPower.displayDevice
        if (dev.isLaptopBattery) {
            const charging = () => dev.state === UPowerDeviceState.Charging
            rows.push({ kind: "info", group: "power", title: "battery", aliases: "charge",
                glyph: () => BatteryState.icon(dev.percentage * 100, charging()),
                right: () => Math.round(dev.percentage * 100) + "%",
                subtitle: () => charging() ? "charging" : dev.state === UPowerDeviceState.FullyCharged ? "full" : "on battery" })
        }
        return rows
    }

    function sessionRows() {
        const act = (title, glyph, aliases, cmd, confirm) => ({
            kind: "action", group: "session", title, glyph, aliases, confirm: !!confirm,
            run: () => Quickshell.execDetached(cmd),
        })
        return [
            { kind: "header", title: "session" },
            act("lock", "\u{f023}", "screen", ["qs", "ipc", "call", "lock", "lock"]),
            act("reload", "\u{f0450}", "restart refresh sway quickshell", ["sh", "-c", "pkill -KILL -x quickshell; swaymsg reload"]),
            act("suspend", "\u{f04b2}", "sleep", ["systemctl", "suspend"]),
            act("logout", "\u{f0343}", "exit quit sway", ["swaymsg", "exit"], true),
            act("reboot", "\u{f0709}", "restart", ["systemctl", "reboot"], true),
            act("shutdown", "\u{f011}", "poweroff off halt", ["systemctl", "poweroff"], true),
        ]
    }

    readonly property var rows: networkRows().concat(bluetoothRows(), audioRows(),
                                                     displayRows(), powerRows(), sessionRows())
}
