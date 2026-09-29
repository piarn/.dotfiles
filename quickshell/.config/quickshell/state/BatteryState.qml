// Battery icon tiers. Nothing to poll here: UPower's own singleton
// (Quickshell.Services.UPower) is already reactive, so Bar.qml and
// BatteryMenu.qml both read it directly.
pragma Singleton
import QtQuick

QtObject {
    // Material's battery set only has 20/30/50/60/80/90 tiers; 10/40/70
    // snap to the nearest (rounding up at the 40/70 midpoints).
    function icon(pct, charging) {
        const chargingIcons = { 10: "\u{f0a2}", 20: "\u{f0a2}", 30: "\u{f0a3}", 40: "\u{f0a4}",
            50: "\u{f0a4}", 60: "\u{f0a5}", 70: "\u{f0a6}", 80: "\u{f0a6}", 90: "\u{f0a7}" }
        const icons = { 10: "\u{f09c}", 20: "\u{f09c}", 30: "\u{f09d}", 40: "\u{f09e}",
            50: "\u{f09e}", 60: "\u{f09f}", 70: "\u{f0a0}", 80: "\u{f0a0}", 90: "\u{f0a1}" }
        const tier = Math.min(90, Math.max(10, Math.round(pct / 10) * 10))
        if (charging) return pct >= 95 ? "\u{e1a3}" : chargingIcons[tier]   // battery_charging_full
        if (pct <= 15) return "\u{e19c}"   // battery_alert
        if (pct >= 95) return "\u{e1a5}"   // battery_full
        return icons[tier]
    }
}
