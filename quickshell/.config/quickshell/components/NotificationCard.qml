// One notification — used both for on-screen toasts and for rows in
// NotificationCenter. Click the body to run the notification's default
// action (or just hide the toast when it has none); [x] dismisses it
// everywhere.
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import quickshell
import "../state"

Rectangle {
    id: root

    required property var notification
    property bool toast: false

    readonly property string imageSource: {
        const n = notification
        if (n.image) return n.image
        if (!n.appIcon) return ""
        if (n.appIcon.startsWith("/")) return "file://" + n.appIcon
        if (n.appIcon.includes("://")) return n.appIcon
        return Quickshell.iconPath(n.appIcon, true)
    }

    implicitHeight: col.implicitHeight + 16
    radius: 6
    color: toast ? Colors.black : Colors.surface
    border.width: toast ? 2 : 1
    border.color: notification.urgency === NotificationUrgency.Critical ? Colors.red
        : toast ? Colors.neon : Colors.dim

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationState.invokeDefault(root.notification)
    }

    Image {
        id: img
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 8
        width: visible ? 32 : 0
        height: 32
        visible: root.imageSource !== "" && status !== Image.Error
        source: root.imageSource
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    Column {
        id: col
        anchors.left: img.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        anchors.leftMargin: img.visible ? 10 : 8
        spacing: 3

        Item {
            width: parent.width
            height: title.implicitHeight

            MonoText {
                id: title
                anchors.left: parent.left
                anchors.right: close.left
                anchors.rightMargin: 6
                font.bold: true
                font.pixelSize: 13
                elide: Text.ElideRight
                text: root.notification.summary || root.notification.appName || "notification"
            }

            TextButton {
                id: close
                anchors.right: parent.right
                label: "x"
                baseColor: Colors.gray2
                onClicked: NotificationState.dismiss(root.notification)
            }
        }

        MonoText {
            visible: root.notification.summary !== "" && root.notification.appName !== ""
            width: parent.width
            font.pixelSize: 11
            color: Colors.gray2
            elide: Text.ElideRight
            text: root.notification.appName
        }

        MonoText {
            visible: text.length > 0
            width: parent.width
            color: Colors.gray2
            wrapMode: Text.Wrap
            maximumLineCount: root.toast ? 4 : 6
            elide: Text.ElideRight
            textFormat: Text.StyledText
            linkColor: Colors.acid
            text: root.notification.body
            onLinkActivated: (link) => Qt.openUrlExternally(link)
        }

        Flow {
            width: parent.width
            spacing: 10
            topPadding: 2
            visible: actionRepeater.count > 0

            Repeater {
                id: actionRepeater
                model: NotificationState.visibleActions(root.notification)

                delegate: TextButton {
                    required property var modelData
                    label: modelData.text
                    onClicked: {
                        modelData.invoke()
                        if (root.toast) NotificationState.hidePopup(root.notification)
                    }
                }
            }
        }
    }
}
