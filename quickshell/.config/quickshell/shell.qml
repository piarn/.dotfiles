// Entry point: `quickshell` (or sway's `exec quickshell`) loads this as the
// "default" config since it sits directly at ~/.config/quickshell/shell.qml.
// Colors come from ~/.rice/quickshell/Colors.qml (see Bar.qml/Launcher.qml),
// re-rendered by ~/.rice/bin/apply-theme — this file has no theme-specific
// content itself.
//
// Layout: state/ holds the pragma-Singleton status backends, popups/ holds
// the click-to-open menus plus the free-standing surfaces (Launcher,
// PowerMenu, LockScreen, toasts, OSD), components/ holds shared UI pieces
// (BarPopup is the shell every bar popup is built on). Bar.qml and this
// file stay at the root since every popup/state type ends up wired through
// one or the other.
import Quickshell
import Quickshell.Io
import QtQuick
import "./popups"
import "./state"

ShellRoot {
    Bar {}
    Launcher {}
    NetworkMenu {}
    BluetoothMenu {}
    BatteryMenu {}
    NotificationCenter {}
    QuickSettings {}
    NotificationToasts {}
    Osd {}
    PowerMenu {}
    LockScreen {}

    // `qs ipc call popup toggle <name>` — network, bluetooth,
    // battery, notifications, quicksettings. Opens on the focused monitor.
    IpcHandler {
        target: "popup"
        function toggle(name: string): void { PopupState.toggle(name) }
        function close(): void { PopupState.close() }
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
