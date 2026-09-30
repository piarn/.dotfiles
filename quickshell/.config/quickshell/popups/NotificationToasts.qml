// On-screen notification toasts, under the island on the focused monitor,
// at the island's 600px width. A small surface sized to its content, so
// everything around it stays clickable. Countdown and stacking
// live in NotificationState; hovering pauses every toast's countdown.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: root

    // Picked when the first toast appears and kept while any are showing,
    // so toasts don't jump monitors as focus moves.
    property var targetScreen: null
    readonly property bool active: NotificationState.popups.length > 0
    onActiveChanged: {
        if (active) targetScreen = IslandState.focusedScreen
        // The surface unmaps under the pointer without a hover-exit.
        else NotificationState.popupsHovered = false
    }

    // Step aside while the island is grown on the same monitor — it covers
    // the same spot. NotificationState pauses the countdown too.
    visible: active && !(IslandState.grown && IslandState.screen === targetScreen)
    screen: targetScreen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    // top-centered; the exclusive zone (island/Spacer.qml) puts it just
    // under the collapsed island
    anchors.top: true
    margins.top: 4
    implicitWidth: 600
    implicitHeight: Math.max(1, stack.implicitHeight)

    HoverHandler {
        onHoveredChanged: NotificationState.popupsHovered = hovered
    }

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            model: NotificationState.popups

            delegate: NotificationCard {
                required property var modelData
                width: stack.width
                notification: modelData
                toast: true
            }
        }
    }
}
