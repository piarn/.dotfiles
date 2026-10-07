// Screen layout picker — the list under the display tile in the system tab
// (island/tabs/SystemTab.qml), opened by the tile's ›. Lists every
// ~/.rice/layouts/*.conf; clicking one applies it (apply-layout <name>,
// which pins it). Layouts whose required outputs aren't connected are
// dimmed and can't be picked; the current one is highlighted and checked.
import QtQuick
import quickshell
import "../state"

Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 2

    Repeater {
        model: RiceState.layouts

        delegate: Rectangle {
            id: row
            required property string modelData
            readonly property bool active: modelData === RiceState.currentLayout
            readonly property bool usable: RiceState.usableLayouts.indexOf(modelData) >= 0
            width: root.width
            height: 28
            color: mouse.containsMouse && row.usable ? Colors.surface : "transparent"

            Marker { visible: row.active }

            Icon {
                id: checkIcon
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                visible: row.active
                font.pixelSize: 13
                color: Colors.neon
                text: "\u{e668}"   // check
            }

            MonoText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10 + checkIcon.width
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: row.active ? Colors.neon : row.usable ? Colors.fg : Colors.gray
                elide: Text.ElideRight
                text: row.modelData + (row.usable ? "" : " · not connected")
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: row.usable && !row.active
                cursorShape: Qt.PointingHandCursor
                onClicked: RiceState.applyLayout(row.modelData)
            }
        }
    }
}
