// Material Symbols glyph — needs ~/.local/share/fonts/MaterialSymbols (see
// ~/.dots/install.sh). styleName pins the variable font to its Regular
// weight/fill instance; without it Qt falls back to an arbitrary axis
// position and glyphs can render inconsistently thin or bold.
import QtQuick
import quickshell

Text {
    font.family: "Material Symbols Outlined"
    font.styleName: "Regular"
    font.pixelSize: 15
    color: Colors.acid
    // QtRendering keeps the icons' fine detail (crop marks, small corner
    // strokes) smooth at this size; NativeRendering's hinting is tuned for
    // legible text and stair-steps a vector icon's curves instead.
    renderType: Text.QtRendering
    antialiasing: true
}
