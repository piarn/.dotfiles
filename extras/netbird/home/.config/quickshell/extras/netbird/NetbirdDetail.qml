// NetBird's expanded panel in the network tab's vpn section: why
// management is unreachable (if it is), peers with their state, and when
// the SSO session expires.
import QtQuick
import quickshell
import "../../components"

Column {
    id: root

    required property var provider
    spacing: 4

    MonoText {
        width: parent.width
        visible: root.provider.active && !root.provider.management && root.provider.managementError !== ""
        leftPadding: 8
        rightPadding: 8
        font.pixelSize: 11
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        color: Colors.amber
        text: "management: " + root.provider.managementError
    }

    MonoText {
        visible: root.provider.peers.length === 0
        leftPadding: 8
        color: Colors.gray
        text: "no peers"
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
            readonly property bool up: modelData.status === "Connected"
            width: ListView.view.width
            height: 22

            MonoText {
                anchors.left: parent.left
                anchors.right: peerIp.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                color: peerRow.up ? Colors.fg : Colors.gray2
                text: (peerRow.up ? "● " : "○ ") + peerRow.modelData.name
            }
            MonoText {
                id: peerIp
                anchors.right: peerStatus.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 11
                color: Colors.gray
                text: peerRow.modelData.ip
            }
            MonoText {
                id: peerStatus
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                horizontalAlignment: Text.AlignRight
                font.pixelSize: 11
                color: peerRow.up ? Colors.neon : Colors.gray
                text: peerRow.modelData.status.toLowerCase()
            }
        }
    }

    MonoText {
        visible: root.provider.expires !== null
        leftPadding: 8
        font.pixelSize: 11
        color: root.provider.expires && root.provider.expires - Date.now() < 3600000 ? Colors.amber : Colors.gray2
        text: root.provider.expires ? "session expires " + Qt.formatDateTime(root.provider.expires, "yyyy-MM-dd HH:mm") : ""
    }
}
