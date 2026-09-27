// ZeroTier's expanded panel in the network popup's vpn section: this
// node's id (what a network admin authorizes), joined networks with their
// state and [leave], and a field to join one by its 16-digit id.
import QtQuick
import quickshell
import "../../components"

Column {
    id: root

    required property var provider
    spacing: 4

    function statusText(s) {
        switch (s) {
            case "OK": return "up"
            case "REQUESTING_CONFIGURATION": return "waiting…"
            case "ACCESS_DENIED": return "not authorized"
            case "NOT_FOUND": return "not found"
            default: return s.toLowerCase().replace(/_/g, " ")
        }
    }

    function submit() {
        const id = joinField.text.trim().toLowerCase()
        if (!/^[0-9a-f]{16}$/.test(id)) return
        root.provider.join(id)
        joinField.text = ""
    }

    MonoText {
        visible: root.provider.address !== ""
        leftPadding: 8
        font.pixelSize: 11
        color: Colors.gray2
        text: "node " + root.provider.address
    }

    Repeater {
        model: root.provider.networks

        delegate: Item {
            id: netRow
            required property var modelData
            readonly property bool up: modelData.status === "OK"
            width: root.width
            height: netCol.implicitHeight + 6

            Column {
                id: netCol
                anchors.left: parent.left
                anchors.right: leaveBtn.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                MonoText {
                    width: parent.width
                    elide: Text.ElideRight
                    color: netRow.up ? Colors.fg : Colors.gray2
                    text: (netRow.up ? "● " : "○ ") + (netRow.modelData.name || netRow.modelData.id)
                }
                MonoText {
                    width: parent.width
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: netRow.modelData.status === "ACCESS_DENIED" || netRow.modelData.status === "NOT_FOUND"
                        ? Colors.amber : Colors.gray
                    text: [root.statusText(netRow.modelData.status), netRow.modelData.ips.join(", "),
                           netRow.modelData.name ? netRow.modelData.id : ""].filter(s => s).join(" · ")
                }
            }

            TextButton {
                id: leaveBtn
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                label: "leave"
                baseColor: Colors.gray2
                enabled: !root.provider.running
                onClicked: root.provider.leave(netRow.modelData.id)
            }
        }
    }

    Item {
        width: parent.width
        height: joinField.implicitHeight

        InputField {
            id: joinField
            anchors.left: parent.left
            anchors.right: joinBtn.left
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            placeholder: "network id to join"
            onAccepted: root.submit()
            onEscaped: { text = ""; input.focus = false }
        }
        TextButton {
            id: joinBtn
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            label: "join"
            enabled: /^[0-9a-fA-F]{16}$/.test(joinField.text.trim()) && !root.provider.running
            onClicked: root.submit()
        }
    }

    // Exclusive keyboard for the popup while typing (see CardWindow).
    Binding {
        target: root.provider
        property: "wantsKeyboard"
        value: joinField.input.activeFocus
    }
}
