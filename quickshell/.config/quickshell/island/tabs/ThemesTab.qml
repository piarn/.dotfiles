// The island's themes tab: every ~/.rice theme as a card — its wallpaper,
// name and palette — with the current one outlined in the accent. Click to
// switch (~/.rice/bin/apply-theme re-renders every app's theme and restarts
// quickshell, so the island comes back collapsed in the new colours).
// Same list as the run tab's `:theme` mode (state/RiceState.qml).
import QtQuick
import quickshell
import "../../state"
import "../../components"
import ".."

Tab {
    id: menu
    name: "themes"

    readonly property int columns: 3
    readonly property int cardWidth: (width - (columns - 1) * Style.gap) / columns
    // the palette roles worth showing, in the theme files' own order
    readonly property var swatches: ["neon", "acid", "red", "amber", "blue", "magenta", "cyan", "fg"]

    onOpened: RiceState.refresh()

    MonoText {
        color: Colors.gray
        text: "themes · " + RiceState.themes.length
    }

    Grid {
        columns: menu.columns
        spacing: Style.gap

        Repeater {
            model: RiceState.themes

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property bool current: modelData.id === RiceState.currentTheme

                width: menu.cardWidth
                height: preview.height + info.implicitHeight + 16
                color: modelData.colors.black || Colors.black
                border.width: current ? 2 : Style.border
                border.color: current ? Colors.neon : cardMouse.containsMouse ? Colors.fg : Colors.dim

                Image {
                    id: preview
                    x: card.border.width
                    y: card.border.width
                    width: parent.width - 2 * card.border.width
                    height: 90
                    source: modelData.wallpaper ? "file://" + modelData.wallpaper : ""
                    sourceSize.width: width * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    clip: true
                }

                Column {
                    id: info
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: preview.bottom
                    anchors.margins: 8
                    spacing: 6

                    MonoText {
                        width: parent.width
                        elide: Text.ElideRight
                        font.bold: card.current
                        color: modelData.colors.fg || Colors.fg
                        text: modelData.name + (card.current ? "  ●" : "")
                    }

                    Row {
                        spacing: 2
                        Repeater {
                            model: menu.swatches
                            Rectangle {
                                required property string modelData
                                width: 14
                                height: 8
                                color: card.modelData.colors[modelData] || "transparent"
                            }
                        }
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: card.current ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!card.current) RiceState.applyTheme(card.modelData.id)
                }
            }
        }
    }
}
