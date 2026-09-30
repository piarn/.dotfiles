// One screen's lock: LockFace fed from the shared state on LockScreen.qml
// (`lock`), with typing on any screen mirrored to every other. Its own
// component, rather than inline in the WlSessionLockSurface, so the same
// wiring can be shown in an ordinary window to check it without locking.
import QtQuick

LockFace {
    id: face

    required property var lock

    now: lock.now
    busy: lock.unlockInProgress
    failed: lock.showFailure
    status: lock.statusMessage

    statusLine.host: lock.host
    statusLine.lockedFor: lock.lockedFor
    statusLine.uptime: lock.uptime
    statusLine.weatherGlyph: lock.weatherGlyph
    statusLine.weather: lock.weather
    statusLine.netGlyph: lock.netGlyph
    statusLine.netLabel: lock.netLabel
    statusLine.vpns: lock.vpns
    statusLine.newNotifications: lock.newNotifications
    statusLine.battery: lock.batteryLevel
    statusLine.charging: lock.charging
    statusLine.batteryGlyph: lock.batteryGlyph

    onTextChanged: lock.currentText = text
    onAccepted: lock.tryUnlock()

    // Reset from the shared (by then empty) text whenever shown: each lock
    // can reuse a surface from the previous one, so a field is never
    // trusted to still be clear.
    function reset() {
        text = lock.currentText
        Qt.callLater(() => focusInput())
    }

    Connections {
        target: face.lock
        function onShowFailureChanged() { if (face.lock.showFailure) face.reject() }
        // Clearing the shared text clears every screen's field. Assigned
        // rather than bound: a TextInput's `text` binding breaks on the
        // first keystroke.
        function onCurrentTextChanged() {
            if (face.text !== face.lock.currentText) face.text = face.lock.currentText
        }
    }
}
