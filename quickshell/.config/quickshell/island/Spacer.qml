// Reserves the collapsed island's height at the top of a screen, so windows
// start below it. The island itself ignores exclusive zones (it grows over
// the windows instead of pushing them), so this is what keeps them clear of
// the strip. Transparent and takes no input: the empty mask lets every
// click through.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    required property var modelData

    screen: modelData
    anchors { top: true; left: true; right: true }
    // 6 above the island + its 30px strip + 4 below
    implicitHeight: 40
    exclusiveZone: 40
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-spacer"
}
