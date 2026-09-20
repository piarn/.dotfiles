// Makes the bar's status popups mutually exclusive: opening one closes
// whichever else was open. Each popup keeps its own *MenuOpen flag on its
// own state singleton — this is just the one choke point that flips them
// all, keyed by name, so adding a new popup means adding one line here.
pragma Singleton
import QtQuick

QtObject {
    readonly property var _get: ({
        network: () => NetworkState.menuOpen,
        bluetooth: () => BluetoothState.menuOpen,
        battery: () => BatteryState.menuOpen,
        volume: () => VolumeState.volumeMenuOpen,
        mic: () => VolumeState.micMenuOpen,
        notifications: () => NotificationState.menuOpen,
    })

    readonly property var _set: ({
        network: (v) => NetworkState.menuOpen = v,
        bluetooth: (v) => BluetoothState.menuOpen = v,
        battery: (v) => BatteryState.menuOpen = v,
        volume: (v) => VolumeState.volumeMenuOpen = v,
        mic: (v) => VolumeState.micMenuOpen = v,
        notifications: (v) => NotificationState.menuOpen = v,
    })

    function toggle(name) {
        const wasOpen = _get[name]()
        for (const key in _set) _set[key](false)
        if (!wasOpen) _set[name](true)
    }
}
