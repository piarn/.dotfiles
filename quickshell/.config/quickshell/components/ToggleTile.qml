// Quick settings tile: icon + title + subtitle, highlighted while `active`.
// Clicking the tile toggles; the optional › on the right opens the full
// popup for that feature (`detail`).
import QtQuick
import quickshell

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasDetail: false
    signal toggled()
    signal detail()

    implicitHeight: 46
    radius: 6
    color: active ? Colors.dim : mouse.containsMouse ? Colors.deep : Colors.surface
    border.width: 1
    border.color: active ? Colors.neon : Colors.dim

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Icon {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 18
        color: root.active ? Colors.neon : Colors.gray2
        text: root.icon
    }

    Column {
        anchors.left: glyph.right
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        MonoText {
            width: parent.width
            font.bold: true
            elide: Text.ElideRight
            color: root.active ? Colors.fg : Colors.gray2
            text: root.title
        }
        MonoText {
            width: parent.width
            visible: text !== ""
            font.pixelSize: 11
            elide: Text.ElideRight
            color: Colors.gray2
            text: root.subtitle
        }
    }

    Rectangle {
        id: chevron
        visible: root.hasDetail
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 1
        width: 26
        radius: 5
        color: chevronMouse.containsMouse ? Colors.deep : "transparent"

        Icon {
            anchors.centerIn: parent
            color: Colors.gray2
            text: "\u{f0142}"
        }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detail()
        }
    }
}
