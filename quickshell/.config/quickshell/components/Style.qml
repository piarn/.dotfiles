// Shape language shared by every surface — the counterpart to the rice's
// Colors (which only carries the palette). Terminal-native on purpose: square
// corners, 1px rules, and the accent spent only on what's active or focused,
// so the shell reads like the same instrument as tmux and nvim.
pragma Singleton
import QtQuick

QtObject {
    readonly property int radius: 0
    readonly property int border: 1
    // Left edge marker on an active tile / selected row, in place of a fill.
    readonly property int marker: 2
    readonly property int pad: 12
    readonly property int gap: 8
    // Level bars: same 16 steps as the volume OSD and sway's volume keys.
    readonly property int segments: 16
    readonly property int fast: 80
}
