// Quick settings tile: icon + title + subtitle in a flat ruled cell. While
// `active` it gets an accent marker down its left edge and accent text —
// no filled bubble. Clicking the tile toggles; the optional › zone on the
// right, split off by a rule, opens the feature's full popup (`detail`).
// Laid out in a grid with spacing -1 so neighbouring rules overlap into one.
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

    implicitHeight: 44
    radius: Style.radius
    color: mouse.containsMouse ? Colors.surface : Colors.black
    border.width: Style.border
    border.color: Colors.dim

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Rectangle {
        visible: root.active
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Style.border
        width: Style.marker
        color: Colors.neon
    }

    Icon {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 16
        color: root.active ? Colors.neon : Colors.gray2
        text: root.icon
    }

    Column {
        anchors.left: glyph.right
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.leftMargin: 9
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        MonoText {
            width: parent.width
            font.bold: root.active
            elide: Text.ElideRight
            color: root.active ? Colors.neon : Colors.fg
            text: root.title.toLowerCase()
        }
        MonoText {
            width: parent.width
            visible: text !== ""
            font.pixelSize: 11
            elide: Text.ElideRight
            color: root.active ? Colors.gray2 : Colors.gray
            text: root.subtitle
        }
    }

    Rectangle {
        id: chevron
        visible: root.hasDetail
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Style.border
        width: 24
        color: chevronMouse.containsMouse ? Colors.dim : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Style.border
            color: Colors.dim
        }

        MonoText {
            anchors.centerIn: parent
            color: chevronMouse.containsMouse ? Colors.fg : Colors.gray2
            text: "›"
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
