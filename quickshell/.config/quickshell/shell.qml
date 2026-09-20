// Entry point: `quickshell` (or sway's `exec quickshell`) loads this as the
// "default" config since it sits directly at ~/.config/quickshell/shell.qml.
// Colors come from ~/.rice/quickshell/Colors.qml (see Bar.qml/Launcher.qml),
// re-rendered by ~/.rice/bin/apply-theme — this file has no theme-specific
// content itself.
//
// Layout: state/ holds the pragma-Singleton status backends, popups/ holds
// the click-to-open menus (plus Launcher/PowerMenu, which aren't tied to a
// bar widget), components/ holds small shared UI pieces. Bar.qml and this
// file stay at the root since every popup/state type ends up wired through
// one or the other.
import Quickshell
import "./popups"

ShellRoot {
    Bar {}
    Launcher {}
    NetworkMenu {}
    BluetoothMenu {}
    BatteryMenu {}
    VolumeMenu {}
    MicMenu {}
    NotificationCenter {}
    PowerMenu {}
    LockScreen {}
}
