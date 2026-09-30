// Tailscale's expanded panel in the network tab's vpn section: the
// login link while one is pending, the exit node picker (click one to route
// everything through it, [none] to stop), and the tailnet's peers.
import QtQuick
import quickshell
import "../../components"

Column {
    id: root

    required property var provider
    spacing: 4

    Item {
        width: parent.width
        height: loginBtn.implicitHeight
        visible: root.provider.authUrl !== ""

        MonoText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            color: Colors.amber
            text: "login pending"
        }
        TextButton {
            id: loginBtn
            anchors.right: parent.right
            anchors.rightMargin: 8
            label: "open login page"
            onClicked: Qt.openUrlExternally(root.provider.authUrl)
        }
    }

    // exit nodes
    Item {
        width: parent.width
        height: noneBtn.implicitHeight
        visible: root.provider.exitNodes.length > 0

        MonoText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            color: Colors.gray
            text: "exit node · " + (root.provider.exitNode ? root.provider.exitNode.name : "none")
        }
        TextButton {
            id: noneBtn
            anchors.right: parent.right
            anchors.rightMargin: 8
            visible: root.provider.exitNode !== null
            label: "none"
            baseColor: Colors.gray2
            enabled: !root.provider.running
            onClicked: root.provider.setExitNode("")
        }
    }

    Repeater {
        model: root.provider.exitNodes

        delegate: Rectangle {
            id: exitRow
            required property var modelData
            width: root.width
            height: 22
            radius: 4
            color: modelData.exitNode ? Colors.dim : exitMouse.containsMouse ? Colors.surface : "transparent"

            MouseArea {
                id: exitMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: exitRow.modelData.online && !exitRow.modelData.exitNode
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.provider.setExitNode(exitRow.modelData.ip)
            }
            MonoText {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                color: exitRow.modelData.exitNode ? Colors.neon : exitRow.modelData.online ? Colors.fg : Colors.gray
                text: exitRow.modelData.name
            }
            MonoText {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 11
                color: Colors.gray
                text: exitRow.modelData.online ? exitRow.modelData.ip : "offline"
            }
        }
    }

    MonoText {
        visible: root.provider.peers.length > 0
        leftPadding: 8
        color: Colors.gray
        text: "peers"
    }

    // Scrolls past 8 rows, like the wi-fi list.
    ListView {
        id: peerList
        width: parent.width
        height: Math.min(contentHeight, 8 * 22)
        visible: count > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: root.provider.peers

        delegate: Item {
            id: peerRow
            required property var modelData
            width: ListView.view.width
            height: 22

            MonoText {
                anchors.left: parent.left
                anchors.right: peerIp.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                color: peerRow.modelData.online ? Colors.fg : Colors.gray2
                text: (peerRow.modelData.online ? "● " : "○ ") + peerRow.modelData.name
            }
            MonoText {
                id: peerIp
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 11
                color: Colors.gray
                text: peerRow.modelData.ip + (peerRow.modelData.os ? "  " + peerRow.modelData.os : "")
            }
        }
    }
}
