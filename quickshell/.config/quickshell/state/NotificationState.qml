// Notification daemon backend — org.freedesktop.Notifications, replacing
// mako/dunst/swaync (nothing else was providing this service; confirmed via
// `busctl --user list` before adding it, since only one process may own that
// D-Bus name at a time). Item root (not QtObject) for the same reason
// BluetoothState.qml is one: NotificationServer is a non-Item child object,
// which needs the generic "data" default property Item has and QtObject
// doesn't.
//
// `muted` is the mute toggle Bar.qml's bell icon flips — while true, incoming
// notifications are neither tracked nor popped up (the sender still gets a
// normal D-Bus reply either way, so apps don't see errors; they just don't
// get shown). Not persisted across a quickshell restart — deliberately: a
// silently-still-muted state surviving a restart/reboot is a worse footgun
// than occasionally having to re-mute.
pragma Singleton
import Quickshell.Services.Notifications
import QtQuick

Item {
    id: root

    property bool muted: false
    function toggleMute() { muted = !muted }

    property bool menuOpen: false

    // Plain property, updated imperatively (see the Connections block below)
    // rather than a live `notifications: server.trackedNotifications.values`
    // binding — that computed form was observed to read back as `undefined`
    // everywhere it was used (Bar.qml, NotificationCenter.qml), for reasons
    // that didn't reproduce in an isolated single-file harness; this sidesteps
    // whatever binding-evaluation-order quirk that was rather than chase it
    // further.
    property var notifications: []

    function refresh() {
        notifications = server.trackedNotifications ? server.trackedNotifications.values : []
    }

    Component.onCompleted: refresh()

    // Two listeners: trackedNotifications itself only becomes non-null once
    // the server's D-Bus registration finishes (trackedNotificationsChanged),
    // and its .values list then changes on every notification arrival/
    // dismissal (valuesChanged) — `target: server.trackedNotifications`
    // rebinds automatically once that stops being null, so this single
    // Connections block ends up covering both.
    Connections {
        target: server
        function onTrackedNotificationsChanged() { root.refresh() }
    }

    Connections {
        target: server.trackedNotifications
        function onValuesChanged() { root.refresh() }
    }

    function dismiss(notification) {
        notification.tracked = false
        notification.dismiss()
    }

    function clearAll() {
        for (const n of notifications) dismiss(n)
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: (notification) => {
            if (root.muted) return
            notification.tracked = true
        }
    }
}
