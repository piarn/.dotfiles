// Session lock screen, replacing swaylock. WlSessionLock speaks the same
// ext-session-lock-v1 protocol swaylock used: the compositor grabs all
// input and, per the Wayland protocol itself, keeps the screen locked and
// painted solid even if this whole quickshell process dies — there is no
// code path here that can accidentally leave the desktop exposed. PamContext
// (Quickshell.Services.Pam) does real PAM authentication against
// /etc/pam.d/quickshell-lock (installed by ~/.dots/install.sh's
// install_pam_lock_config — see that file for why it's a separate service
// rather than reusing swaylock's or login's).
//
// Triggered by `qs ipc call lock lock`, always through ~/.local/bin/dots-lock
// ($mod+Escape, swayidle, the command center's `:lock`, qs-watchdog), which
// confirms the lock with isLocked() below and falls back to swaylock when
// this lock screen doesn't come up. Deliberately no
// Escape-to-dismiss keybinding anywhere in this file: unlike the command
// center, this is a security surface, so the only way out is a correct
// password.
//
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import QtQuick
import quickshell
import "../state"
import "./lock"

// Non-visual wrapper: WlSessionLock's own default property is `surface`
// (a single Component, not a generic child list), so the PamContext/
// IpcHandler below have to live as its siblings rather than its children —
// nesting them inside WlSessionLock silently drops them (no QML error, they
// just never get created). Item has the generic "data" default property
// that holds arbitrary children, same reason state/BluetoothState.qml's
// singleton is an Item rather than a QtObject.
Item {
    id: root

    // Shared across every screen's surface (multi-monitor: typing on one
    // output's surface should unlock all of them at once) — referenced by
    // id from inside the per-screen `surface` Component below. Direct id
    // access across a Component boundary works here the same way it does in
    // any Repeater delegate: ids resolve against the whole document, not the instantiation point.
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property string statusMessage: ""

    function tryUnlock() {
        if (currentText === "" || unlockInProgress) return
        unlockInProgress = true
        showFailure = false
        pam.start()
    }

    // Everything the status line shows, computed once here for all screens.
    property date now: new Date()
    property date lockedAt: new Date()
    // notifications present when locking; the rest arrived while locked
    property var notificationsAtLock: []

    readonly property string host: Quickshell.env("USER") + "@" + hostnameFile.text().trim()
    readonly property string lockedFor: {
        void root.now
        return duration((root.now - root.lockedAt) / 1000)
    }
    readonly property string uptime: {
        void root.now
        return duration(parseFloat(uptimeFile.text()) || 0)
    }
    readonly property int newNotifications: NotificationState.notifications
        .filter(n => !notificationsAtLock.includes(n)).length

    readonly property var net: NetworkState.primary
    readonly property string netLabel: !net ? "offline"
        : net.type === "wifi" ? net.connection
        : net.type === "wwan" ? "mobile" : "wired"

    readonly property string weatherGlyph: WeatherState.glyph
    readonly property string weather: WeatherState.available ? WeatherState.temp + " " + WeatherState.desc : ""

    readonly property string netGlyph: NetworkState.icon(net)
    readonly property var vpns: NetworkState.activeVpns

    readonly property var battery: UPower.displayDevice
    readonly property bool charging: battery.state === UPowerDeviceState.Charging
        || battery.state === UPowerDeviceState.FullyCharged
    // 0..1, or -1 on a machine without one (hides it)
    readonly property real batteryLevel: battery.isLaptopBattery ? battery.percentage : -1
    readonly property string batteryGlyph: BatteryState.icon(battery.percentage * 100, charging)

    // 90 -> "1m", 4000 -> "1h 6m", 190000 -> "2d 4h"
    function duration(secs) {
        const m = Math.floor(secs / 60), h = Math.floor(m / 60), d = Math.floor(h / 24)
        if (d > 0) return d + "d " + (h % 24) + "h"
        if (h > 0) return h + "h " + (m % 60) + "m"
        return Math.max(m, 0) + "m"
    }

    // Always ticking (a Date every second is nothing): bound to
    // sessionLock.locked it never started for the lock a fresh instance
    // takes from lockFlag during startup, and that lock's clock stayed
    // frozen at the startup minute.
    Timer {
        running: true
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date()
            if (root.now.getSeconds() === 0) uptimeFile.reload()
        }
    }

    FileView { id: hostnameFile; path: "/proc/sys/kernel/hostname" }
    FileView { id: uptimeFile; path: "/proc/uptime" }

    WlSessionLock {
        id: sessionLock

        onLockStateChanged: {
            lockFlag.setText(locked ? "1\n" : "0\n")
            if (locked) {
                root.currentText = ""
                root.showFailure = false
                root.statusMessage = ""
                root.lockedAt = new Date()
                root.notificationsAtLock = NotificationState.notifications.slice()
                uptimeFile.reload()
            }
        }

        surface: Component {
            WlSessionLockSurface {
                id: surface
                color: Colors.black

                onVisibleChanged: if (visible) view.reset()

                LockView {
                    id: view
                    anchors.fill: parent
                    lock: root
                }
            }
        }
    }

    // 1 while locked. Any instance that starts up (crash, restart, config
    // reload) and finds 1 here locks again straight away: when the lock
    // client goes away while locked, sway keeps the screen covered in solid
    // red with no password prompt, and a new lock client is the only way
    // back in short of killing the session.
    FileView {
        id: lockFlag
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-locked"
        printErrors: false
        onLoaded: if (text().trim() === "1" && !sessionLock.locked) sessionLock.locked = true
    }

    PamContext {
        id: pam
        config: "quickshell-lock"

        onPamMessage: {
            if (responseRequired) respond(root.currentText)
            else if (message.length > 0) root.statusMessage = message
        }

        onCompleted: (result) => {
            root.unlockInProgress = false
            if (result === PamResult.Success) {
                sessionLock.locked = false
                // don't keep the password in memory until the next lock
                root.currentText = ""
                root.statusMessage = ""
            } else {
                root.currentText = ""
                root.showFailure = true
                root.statusMessage = "wrong password"
            }
        }

        onError: (err) => {
            root.unlockInProgress = false
            root.showFailure = true
            root.statusMessage = PamError.toString(err)
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { sessionLock.locked = true }
        // dots-lock's proof the lock engaged (`qs ipc call` itself exits 0
        // even when this target doesn't exist): secure, i.e. confirmed by
        // the compositor, not just requested
        function isLocked(): bool { return sessionLock.secure }
    }
}
