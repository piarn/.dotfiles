// A tab's section line, as in the network tab: "title · count" on the
// left in grey, its actions ([TextButton]s, as children) on the right.
import QtQuick
import quickshell

Item {
    id: header

    property string title: ""
    property string count: ""
    default property alias actions: actionRow.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(label.implicitHeight, actionRow.implicitHeight)

    MonoText {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: Colors.gray
        text: header.title + (header.count !== "" ? " · " + header.count : "")
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
    }
}
