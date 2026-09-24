// "Keep awake" toggle from the quick settings panel. Bar.qml hangs an
// IdleInhibitor off each bar window bound to this, which is what swayidle
// honours (idle-inhibit protocol) — logind inhibitors don't stop it.
pragma Singleton
import QtQuick

QtObject {
    property bool inhibit: false
}
