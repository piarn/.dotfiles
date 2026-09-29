// One row of the hub's list. `item` describes it; any field may be a
// function, evaluated here so live values stay reactive per row (see
// SystemSection). Kinds:
//   header  group label, never selected
//   action  runs and closes the hub (`confirm`: needs Enter twice)
//   toggle  on/off, stays open            choice  ● one of a set
//   level   0..1 bar: set(v), adjust(d); Enter/run mutes
//   page    Enter opens item.rows()       info    read-only
//   theme   a rice theme with wallpaper + palette preview
import Quickshell
import Quickshell.Widgets
import QtQuick
import quickshell
import "../../components"

Rectangle {
    id: row

    required property var item
    property bool current: false
    property bool armed: false        // confirm action waiting for its second Enter
    property string tag: ""           // section/group, shown on search results
    signal clicked(bool alt)

    function v(x) { return typeof x === "function" ? x() : x }

    readonly property string kind: item.kind || "action"
    readonly property bool on: !!v(item.on)
    readonly property string subtitle: v(item.subtitle) || ""
    readonly property string rightText: v(item.right) || ""

    width: ListView.view ? ListView.view.width : 0
    height: kind === "header" ? 30 : kind === "theme" ? 76 : 40
    color: kind !== "header" && (current || mouse.containsMouse) ? Colors.surface : "transparent"

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: row.kind !== "header"
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => row.clicked(m.modifiers & Qt.ShiftModifier)
    }

    Marker { visible: row.current }

    // ── group ───────────────
    Item {
        visible: row.kind === "header"
        anchors.fill: parent

        MonoText {
            id: headerText
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            font.pixelSize: 11
            font.bold: true
            color: Colors.acid
            text: row.item.title
        }
        Rectangle {
            anchors.left: headerText.right
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            anchors.verticalCenter: headerText.verticalCenter
            height: 1
            color: Colors.dim
        }
    }

    // icon / glyph / wallpaper
    Item {
        id: lead
        visible: row.kind !== "header"
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: row.kind === "theme" ? 112 : 26
        height: row.kind === "theme" ? 63 : 26

        IconImage {
            anchors.centerIn: parent
            implicitSize: 26
            visible: !!row.item.icon
            source: row.item.icon ? Quickshell.iconPath(row.item.icon, "application-x-executable") : ""
        }
        Icon {
            anchors.centerIn: parent
            visible: !row.item.icon && row.kind !== "theme"
            font.pixelSize: 18
            color: row.on || row.current ? Colors.neon : Colors.gray2
            text: row.v(row.item.glyph) || ""
        }
        Image {
            anchors.fill: parent
            visible: row.kind === "theme"
            source: row.kind === "theme" && row.item.wallpaper ? "file://" + row.item.wallpaper : ""
            sourceSize.width: 224
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            visible: row.kind === "theme"
            color: "transparent"
            border.width: Style.border
            border.color: row.on ? Colors.neon : Colors.dim
        }
    }

    Column {
        visible: row.kind !== "header"
        anchors.left: lead.right
        anchors.right: trail.left
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: row.kind === "theme" ? 6 : 1

        MonoText {
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: 14
            font.bold: row.on && row.kind !== "action"
            color: row.current || row.on ? Colors.neon : Colors.fg
            text: row.item.title
        }
        MonoText {
            width: parent.width
            visible: text !== ""
            elide: Text.ElideMiddle
            font.pixelSize: 11
            color: Colors.gray2
            text: row.subtitle
        }
        // palette strip: the roles every template renders from
        Row {
            visible: row.kind === "theme"
            spacing: 0

            Repeater {
                model: row.kind === "theme"
                    ? ["black", "surface", "dim", "neon", "acid", "fg", "red", "amber", "blue", "magenta", "cyan"]
                    : []

                delegate: Rectangle {
                    required property string modelData
                    width: 18
                    height: 12
                    color: row.item.colors[modelData] || "transparent"
                    border.width: modelData === "black" ? Style.border : 0
                    border.color: Colors.dim
                }
            }
        }
    }

    // right side: tag, then the kind's control
    Row {
        id: trail
        visible: row.kind !== "header"
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.tag !== ""
            font.pixelSize: 11
            color: Colors.gray
            text: row.tag
        }
        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.armed
            color: Colors.red
            text: "enter again to " + row.item.title
        }
        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.rightText !== ""
            color: Colors.gray2
            text: row.rightText
        }
        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.kind === "toggle"
            font.bold: row.on
            color: row.on ? Colors.neon : Colors.gray
            text: row.on ? "[on] " : "[off]"
        }
        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.kind === "choice" || row.kind === "theme"
            color: row.on ? Colors.neon : Colors.gray
            text: row.on ? "●" : "○"
        }
        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.kind === "page"
            color: Colors.gray2
            text: "›"
        }
        LevelSlider {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.kind === "level"
            width: 240
            value: row.kind === "level" ? row.v(row.item.value) : 0
            muted: row.kind === "level" && !!row.v(row.item.muted)
            onMoved: (x) => row.item.set(x)
            onStepped: (d) => row.item.adjust(d)
        }
        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.kind === "level"
            width: 40
            horizontalAlignment: Text.AlignRight
            color: row.kind === "level" && row.v(row.item.muted) ? Colors.red : Colors.gray2
            text: row.kind !== "level" ? "" : row.v(row.item.muted) ? "mute"
                : Math.round(row.v(row.item.value) * 100) + "%"
        }
    }
}
