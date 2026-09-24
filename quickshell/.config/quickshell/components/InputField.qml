// Single-line text box: themed frame, placeholder, optional password echo.
// Enter emits accepted(), Escape escaped(); `input` is the TextInput for
// focus handling (forceActiveFocus, KeyNavigation).
import QtQuick
import quickshell

Rectangle {
    id: root

    property alias text: field.text
    property alias input: field
    property string placeholder: ""
    property bool password: false
    signal accepted()
    signal escaped()

    implicitWidth: 200
    implicitHeight: 24
    radius: 3
    color: Colors.surface
    border.color: field.activeFocus ? Colors.neon : Colors.dim
    border.width: 1

    TextInput {
        id: field
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        verticalAlignment: TextInput.AlignVCenter
        font.family: "monospace"
        font.pixelSize: 12
        color: Colors.fg
        clip: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
        Keys.onEscapePressed: root.escaped()
    }

    MonoText {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        visible: field.text === ""
        color: Colors.gray
        text: root.placeholder
    }
}
