// Accent bar down a row's left edge — how the shell marks the selected or
// active row, in place of a filled highlight. Drop it into the row and bind
// `visible`.
import QtQuick
import quickshell

Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Style.marker
    color: Colors.neon
}
