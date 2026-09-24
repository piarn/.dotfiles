// A themed card on a layer surface exactly the card's size — the base for
// bar popups (BarPopup, top-right) and the launcher/power menu (centered).
// Children go straight into the card; set cardWidth/cardHeight.
//
// Deliberately not fullscreen: the popups used to be transparent fullscreen
// click catchers holding the keyboard exclusively, so when quickshell hung
// with one open, every click and key went to a frozen surface. Now nothing
// outside the card is covered.
//
// Keyboard focus, as sway 1.9 actually behaves (tested):
//  - on-demand (default): a surface mapped right after a click on this
//    client (the bar) gets focus; one mapped out of the blue (IPC/keybind)
//    doesn't. Losing focus after having it means another window was
//    clicked, which is reported as dismissed() — the "click outside".
//  - exclusive (needsKeyboard: true): always gets focus, but never loses it,
//    so there's no click-outside signal. For keyboard-driven surfaces
//    (launcher, power menu) and while a text field is open. Switching back
//    to on-demand makes sway drop focus immediately.
//    clickAwayCloses covers the missing click-outside for these: while
//    shown, a transparent surface on every screen sits just under the
//    card, and a click on it counts as dismissed() — the click itself is
//    swallowed, not passed to the window beneath (same as rofi).
// xdg_popup grabs would be the textbook answer, but sway doesn't honour
// them for layer-shell popups.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell

PanelWindow {
    id: root

    property bool centered: false
    property real cardWidth: 300
    property real cardHeight: 200
    default property alias content: card.data

    // Escape, or focus went elsewhere.
    signal dismissed()

    // What gets keyboard focus when shown (e.g. the launcher's search field).
    property Item initialFocus: catcher
    property bool needsKeyboard: false
    property bool clickAwayCloses: false
    // Leaving exclusive mode drops focus; don't treat that as a dismissal.
    onNeedsKeyboardChanged: if (!needsKeyboard) { hadFocus = false; blurCheck.stop() }

    // Take keyboard focus back from a text field so Escape works again.
    function focusCatcher() { catcher.forceActiveFocus() }

    // Overlay so the card stays above its Top-layer click-away catchers.
    WlrLayershell.layer: clickAwayCloses ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: needsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    // Bar popups: zone 0 so sway places them below the bar's exclusive zone.
    // Centered ones: no anchors at all, which layer-shell centers on the output.
    exclusionMode: centered ? ExclusionMode.Ignore : ExclusionMode.Normal
    color: "transparent"
    anchors.top: !centered
    anchors.right: !centered
    margins.top: centered ? 0 : 6
    margins.right: centered ? 0 : 10
    implicitWidth: cardWidth
    implicitHeight: cardHeight

    property bool hadFocus: false

    Variants {
        model: root.clickAwayCloses ? Quickshell.screens : []

        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.visible
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-clickaway"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.dismissed()
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            hadFocus = false
            Qt.callLater(() => root.initialFocus.forceActiveFocus())
        }
    }

    // Debounced, and ignored while the pointer is over the card: in testing,
    // a click inside an on-demand layer surface could also drop its focus.
    Timer {
        id: blurCheck
        interval: 150
        onTriggered: if (root.visible && !card.Window.active && !hover.hovered) root.dismissed()
    }

    Rectangle {
        id: card
        width: root.cardWidth
        height: root.cardHeight
        color: Colors.black
        border.color: Colors.neon
        border.width: 2
        radius: 6

        Window.onActiveChanged: {
            if (Window.active) {
                root.hadFocus = true
                blurCheck.stop()
            } else if (root.hadFocus) {
                blurCheck.restart()
            }
        }

        HoverHandler { id: hover }

        Item {
            id: catcher
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.dismissed()
        }
    }
}
