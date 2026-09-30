// Entry point: `quickshell` (or sway's `exec quickshell`) loads this as the
// "default" config since it sits directly at ~/.config/quickshell/shell.qml.
// Colors come from ~/.rice/quickshell/Colors.qml, re-rendered by
// ~/.rice/bin/apply-theme — this file has no theme-specific content itself.
//
// Layout: island/ is the shell's one surface — per screen a 600px Island
// (collapsed: the Strip; grown: the tabbed Panel, island/tabs/) plus a
// Spacer reserving its height; state/ holds the pragma-Singleton status
// backends (IslandState: which tab is open where); popups/ holds the
// free-standing surfaces (LockScreen, toasts, OSD); components/ holds
// shared UI pieces.
import Quickshell
import Quickshell.Io
import QtQuick
import "./popups"
import "./state"
import "./island"

ShellRoot {
    // No hot reload on file changes: reloading mid-edit has crashed
    // quickshell (EGL surface errors), which while locked leaves sway's red
    // lock-failure screen. Apply changes with $mod+Shift+c instead.
    settings.watchFiles: false

    // Every tab exists once, here; the grown screen's Island adopts it and
    // hands it back to this holder when it collapses.
    Item {
        visible: false
        Panel { id: sharedPanel }
    }

    Variants {
        model: Quickshell.screens
        delegate: Spacer {}
    }
    Variants {
        model: Quickshell.screens
        delegate: Island { panel: sharedPanel }
    }

    NotificationToasts {}
    Osd {}
    LockScreen {}

    // `qs ipc call popup toggle <name>` — an island tab (system, calendar,
    // notifications, network, run, clipboard) or an old popup name
    // (quicksettings/battery → system, bluetooth → network; see
    // island/routes.js). Opens on the focused monitor.
    IpcHandler {
        target: "popup"
        function toggle(name: string): void { IslandState.toggle(name) }
        function close(): void { IslandState.close() }
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
