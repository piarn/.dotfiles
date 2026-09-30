// One row of the command center's result list. `item` describes it; any
// field may be a function, evaluated here so live values stay reactive per
// row. Kinds:
//   header  group label, never selected
//   action  runs and closes the command center (`confirm`: needs Enter twice)
//   toggle  on/off, stays open            choice  ● one of a set
//   level   0..1 bar: set(v), adjust(d); Enter/run mutes
//   page    Enter opens item.rows()       info    read-only
//   theme   a rice theme with wallpaper + palette preview
// Any row can carry `swatch` (a colour) in place of its icon/glyph.
//   status  the home screen's live status line (text), never selected
//   chips   a row of quick toggles (chips: [{title, on, run}]); ←→ pick
//           one when the row is selected, Enter or a click flips it
import Quickshell
import Quickshell.Widgets
import QtQuick
import quickshell
import "../../../components"

Rectangle {
    id: row

    required property var item
    property bool current: false
    property bool armed: false        // confirm action waiting for its second Enter
    property string tag: ""           // section/group, shown on search results
    property int chip: 0              // selected chip on a chips row
    signal clicked(bool alt)

    function v(x) { return typeof x === "function" ? x() : x }

    readonly property string kind: item.kind || "action"
    readonly property bool on: !!v(item.on)
    readonly property string subtitle: v(item.subtitle) || ""
    readonly property string rightText: v(item.right) || ""

    width: ListView.view ? ListView.view.width : 0
    readonly property bool plain: kind === "header" || kind === "status"
    height: kind === "header" ? 26 : kind === "theme" ? 68 : kind === "status" ? 26 : kind === "chips" ? 38 : 34
    color: !plain && kind !== "chips" && (current || mouse.containsMouse) ? Colors.surface : "transparent"

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !row.plain && row.kind !== "chips"
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => row.clicked(m.modifiers & Qt.ShiftModifier)
    }

    Marker { visible: row.current && row.kind !== "chips" }

    MonoText {
        visible: row.kind === "status"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        color: Colors.gray2
        text: row.kind === "status" ? row.v(row.item.text) : ""
    }

    // quick toggles: flat ruled cells like quick settings' tiles
    Row {
        visible: row.kind === "chips"
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: -1

        Repeater {
            model: row.kind === "chips" ? row.item.chips : []

            delegate: Rectangle {
                id: chipCell
                required property var modelData
                required property int index
                readonly property bool on: !!row.v(modelData.on)
                readonly property bool picked: row.current && index === row.chip
                width: chipText.implicitWidth + 24
                height: 30
                color: picked || chipMouse.containsMouse ? Colors.surface : Colors.black
                border.width: Style.border
                border.color: picked ? Colors.neon : Colors.dim

                Rectangle {
                    visible: chipCell.on
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Style.border
                    width: Style.marker
                    color: Colors.neon
                }
                MonoText {
                    id: chipText
                    anchors.centerIn: parent
                    font.bold: chipCell.on
                    color: chipCell.on ? Colors.neon : Colors.gray2
                    text: row.v(chipCell.modelData.title)
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chipCell.modelData.run()
                }
            }
        }
    }

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
            text: row.v(row.item.title) || ""
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
        visible: !row.plain && row.kind !== "chips"
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
        // a colour entry (clipboard): the colour itself
        Rectangle {
            anchors.centerIn: parent
            visible: !!row.item.swatch
            width: 18
            height: 18
            color: row.item.swatch || "transparent"
            border.width: Style.border
            border.color: Colors.dim
        }
        Icon {
            anchors.centerIn: parent
            visible: !row.item.icon && !row.item.swatch && row.kind !== "theme"
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
        visible: !row.plain && row.kind !== "chips"
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
            text: row.v(row.item.title) || ""
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
        visible: !row.plain && row.kind !== "chips"
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
            width: 200
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
