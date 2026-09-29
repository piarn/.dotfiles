// Entry point: `quickshell` (or sway's `exec quickshell`) loads this as the
// "default" config since it sits directly at ~/.config/quickshell/shell.qml.
// Colors come from ~/.rice/quickshell/Colors.qml (see Bar.qml/Hub.qml),
// re-rendered by ~/.rice/bin/apply-theme — this file has no theme-specific
// content itself.
//
// Layout: state/ holds the pragma-Singleton status backends, popups/ holds
// the click-to-open menus plus the free-standing surfaces (Hub — the
// command center — and the mini Runner, ClipboardMenu, LockScreen, toasts, OSD; the
// hub's sections live in popups/hub/), components/ holds
// shared UI pieces (BarPopup is the shell every bar popup is built on).
// Bar.qml and this file stay at the root since every popup/state type ends
// up wired through one or the other.
import Quickshell
import Quickshell.Io
import QtQuick
import "./popups"
import "./state"

ShellRoot {
    // No hot reload on file changes: reloading mid-edit has crashed
    // quickshell (EGL surface errors), which while locked leaves sway's red
    // lock-failure screen. Apply changes with $mod+Shift+c instead.
    settings.watchFiles: false

    Bar {}
    Hub {}
    Runner {}
    ClipboardMenu {}
    NetworkMenu {}
    BatteryMenu {}
    NotificationCenter {}
    QuickSettings {}
    NotificationToasts {}
    Osd {}
    LockScreen {}

    // `qs ipc call popup toggle <name>` — quicksettings ($mod+n), network,
    // battery, notifications. Opens on the focused monitor. "bluetooth"
    // still works: it's a section of the network popup now.
    IpcHandler {
        target: "popup"
        function toggle(name: string): void { PopupState.toggle(name === "bluetooth" ? "network" : name) }
        function close(): void { PopupState.close() }
    }

    // `qs ipc call vpn toggle mullvad` — connect/disconnect a VPN provider
    // extra by name (see state/ExtrasState.qml), e.g. from a sway bind.
    IpcHandler {
        target: "vpn"
        function toggle(name: string): void {
            const v = ExtrasState.vpn(name)
            if (v && v.available) v.toggle()
        }
    }

    // `qs ipc call idle toggle` — the quick settings "keep awake" tile.
    IpcHandler {
        target: "idle"
        function toggle(): void { IdleState.inhibit = !IdleState.inhibit }
    }

    // Liveness signal for ~/.local/bin/qs-watchdog, which SIGKILLs and
    // restarts quickshell once this goes stale (a hung instance with a
    // popup open would otherwise hold all input hostage).
    FileView {
        id: heartbeat
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-heartbeat"
        printErrors: false
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: heartbeat.setText(Date.now() + "\n")
    }

    // Sway's brightness keys (`qs ipc call brightness up`); see
    // state/BrightnessState.qml for why this isn't brightnessctl.
    IpcHandler {
        target: "brightness"
        function up(): void { BrightnessState.adjust(BrightnessState.step) }
        function down(): void { BrightnessState.adjust(-BrightnessState.step) }
    }
}
