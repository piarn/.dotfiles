// Notification daemon backend — org.freedesktop.Notifications, replacing
// mako/dunst/swaync (nothing else was providing this service; confirmed via
// `busctl --user list` before adding it, since only one process may own that
// D-Bus name at a time). Item root (not QtObject) for the same reason
// BluetoothState.qml is one: NotificationServer is a non-Item child object,
// which needs the generic "data" default property Item has and QtObject
// doesn't.
//
// Every notification is tracked (listed in NotificationCenter until
// dismissed); `popups` is the subset currently shown as on-screen toasts
// (popups/NotificationToasts.qml), each with its own countdown that pauses
// while the pointer is over the toasts or a bar popup covers them. `dnd`
// (do not disturb) suppresses toasts only — notifications still land in
// the center — and critical ones break through it. Not persisted across a
// quickshell restart, on purpose: a silently-still-muted state surviving a
// reboot is a worse footgun than occasionally re-enabling it.
pragma Singleton
import Quickshell.Services.Notifications
import QtQuick

Item {
    id: root

    property bool dnd: false
    function toggleDnd() { dnd = !dnd }

    readonly property int maxPopups: 4
    readonly property int defaultTimeout: 6000

    // Plain property, updated imperatively (see the Connections block below)
    // rather than a live `notifications: server.trackedNotifications.values`
    // binding — that computed form was observed to read back as `undefined`
    // everywhere it was used (Bar.qml, NotificationCenter.qml), for reasons
    // that didn't reproduce in an isolated single-file harness; this sidesteps
    // whatever binding-evaluation-order quirk that was rather than chase it
    // further.
    property var notifications: []
    property var popups: []
    property bool popupsHovered: false
    // notification id -> ms left on screen (Infinity for critical)
    property var remaining: ({})

    function refresh() {
        notifications = server.trackedNotifications ? server.trackedNotifications.values.slice() : []
        // Drop toasts whose notification was closed by its app or dismissed
        // from the center.
        const live = popups.filter(n => notifications.includes(n))
        if (live.length !== popups.length) popups = live
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

    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical) return Infinity
        // Quickshell converts the spec's ms to seconds; the guard is for a
        // build that passes ms straight through.
        const t = n.expireTimeout
        if (t > 0) return t < 1000 ? t * 1000 : t
        return n.urgency === NotificationUrgency.Low ? defaultTimeout / 2 : defaultTimeout
    }

    function showPopup(n) {
        const r = Object.assign({}, remaining)
        r[n.id] = timeoutFor(n)
        remaining = r
        // Newest on top; a replaced notification (same object) moves back up.
        popups = [n].concat(popups.filter(p => p !== n)).slice(0, maxPopups)
    }

    // Removes the toast only; the notification stays in the center.
    function hidePopup(n) {
        popups = popups.filter(p => p !== n)
    }

    function dismiss(n) {
        hidePopup(n)
        n.tracked = false
        n.dismiss()
    }

    function clearAll() {
        for (const n of notifications.slice()) dismiss(n)
    }

    function invokeDefault(n) {
        const action = n.actions.find(a => a.identifier === "default")
        if (action) action.invoke()
        else hidePopup(n)
    }

    // Actions other than "default" (that one is the click-on-body action).
    function visibleActions(n) {
        return n.actions.filter(a => a.identifier !== "default" && a.text)
    }

    Timer {
        interval: 200
        repeat: true
        running: root.popups.length > 0 && !root.popupsHovered && PopupState.current === ""
        onTriggered: {
            const r = Object.assign({}, root.remaining)
            const expired = []
            for (const n of root.popups) {
                r[n.id] = (r[n.id] === undefined ? root.defaultTimeout : r[n.id]) - interval
                if (r[n.id] <= 0) expired.push(n)
            }
            root.remaining = r
            if (expired.length) root.popups = root.popups.filter(n => !expired.includes(n))
        }
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true
            if (!root.dnd || notification.urgency === NotificationUrgency.Critical)
                root.showPopup(notification)
        }
    }
}
