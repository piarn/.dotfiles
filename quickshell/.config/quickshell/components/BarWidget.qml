// One bar status icon: a glyph, an optional solid/hollow dot after it, and
// a click that toggles `popup` on this bar's own screen. Middle click and
// wheel are forwarded for widgets that use them (volume/mic).
import QtQuick
import quickshell
import "../state"

Item {
    id: root

    required property var screen
    property string popup: ""
    property alias icon: glyph.text
    property alias iconColor: glyph.color
    property alias iconSize: glyph.font.pixelSize
    property bool showDot: false
    property bool dotFilled: false

    signal middleClicked()
    signal wheeled(int delta)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Row {
        id: row
        spacing: 4

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
        }

        // Plain Unicode dots instead of nerd font glyphs — those render at
        // noticeably different visual weights from each other at the same
        // pixelSize.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showDot
            font.family: "monospace"
            font.pixelSize: 11
            color: Colors.acid
            text: root.dotFilled ? "●" : "○"
        }
    }

    // No hover tooltips on bar widgets: a child Rectangle anchored below the
    // icon gets clipped by the bar's own 32px-tall surface (layer-shell
    // surfaces can't draw outside their bounds). Details live in the popup.
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) root.middleClicked()
            else if (root.popup) PopupState.toggle(root.popup, root.screen)
        }
        onWheel: (wheel) => root.wheeled(wheel.angleDelta.y)
    }
}
