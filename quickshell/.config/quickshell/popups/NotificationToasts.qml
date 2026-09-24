// On-screen notification toasts, top-right under the bar on the focused
// monitor. A small surface sized to its content (like the bar popups, see
// CardWindow), so everything around it stays clickable. Countdown and stacking
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
        if (active) targetScreen = PopupState.focusedScreen
        // The surface unmaps under the pointer without a hover-exit.
        else NotificationState.popupsHovered = false
    }

    // Step aside while a bar popup is open on the same monitor — both live
    // in the top-right corner. NotificationState pauses the countdown too.
    visible: active && !(PopupState.current !== "" && PopupState.screen === targetScreen)
    screen: targetScreen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins.top: 6
    margins.right: 10
    implicitWidth: 360
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
