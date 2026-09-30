// One seven-segment digit, drawn from square blocks like the rest of the
// shell (no rounded or slanted segments). Unlit segments stay faintly
// visible, the way an LCD's do, so the clock reads as an instrument rather
// than as text. `value` -1 draws every segment unlit.
import QtQuick
import quickshell

Item {
    id: root

    property int value: -1
    property real thickness: 13
    property color litColor: Colors.neon
    property color unlitColor: Colors.deep

    implicitWidth: 74
    implicitHeight: 132

    // segments a..g, clockwise from the top, g in the middle
    readonly property var digits: [
        "abcdef", "bc", "abdeg", "abcdg", "bcfg",
        "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"
    ]
    readonly property string lit: value >= 0 && value <= 9 ? digits[value] : ""

    readonly property real t: thickness
    readonly property real half: (height - 3 * t) / 2   // vertical segment length

    component Segment: Rectangle {
        property string name
        color: root.lit.indexOf(name) >= 0 ? root.litColor : root.unlitColor
        Behavior on color { ColorAnimation { duration: Style.fast } }
    }

    Segment { name: "a"; x: root.t; y: 0; width: root.width - 2 * root.t; height: root.t }
    Segment { name: "b"; x: root.width - root.t; y: root.t; width: root.t; height: root.half }
    Segment { name: "c"; x: root.width - root.t; y: 2 * root.t + root.half; width: root.t; height: root.half }
    Segment { name: "d"; x: root.t; y: root.height - root.t; width: root.width - 2 * root.t; height: root.t }
    Segment { name: "e"; x: 0; y: 2 * root.t + root.half; width: root.t; height: root.half }
    Segment { name: "f"; x: 0; y: root.t; width: root.t; height: root.half }
    Segment { name: "g"; x: root.t; y: root.t + root.half; width: root.width - 2 * root.t; height: root.t }
}
