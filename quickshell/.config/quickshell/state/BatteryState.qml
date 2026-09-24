// Battery icon tiers. Nothing to poll here: UPower's own singleton
// (Quickshell.Services.UPower) is already reactive, so Bar.qml and
// BatteryMenu.qml both read it directly.
pragma Singleton
import QtQuick

QtObject {
    function icon(pct, charging) {
        const chargingIcons = { 10: "\u{f089c}", 20: "\u{f0086}", 30: "\u{f0087}", 40: "\u{f0088}",
            50: "\u{f089d}", 60: "\u{f0089}", 70: "\u{f089e}", 80: "\u{f008a}", 90: "\u{f008b}" }
        const icons = { 10: "\u{f007a}", 20: "\u{f007b}", 30: "\u{f007c}", 40: "\u{f007d}",
            50: "\u{f007e}", 60: "\u{f007f}", 70: "\u{f0080}", 80: "\u{f0081}", 90: "\u{f0082}" }
        const tier = Math.min(90, Math.max(10, Math.round(pct / 10) * 10))
        if (charging) return pct >= 95 ? "\u{f0085}" : chargingIcons[tier]
        if (pct <= 15) return "\u{f0083}"
        if (pct >= 95) return "\u{f0079}"
        return icons[tier]
    }
}
