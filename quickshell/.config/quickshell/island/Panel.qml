// The grown island's contents: the tab row, then the open tab. Created once
// (shell.qml) so every tab — its state, its IPC handler — exists once;
// whichever screen's Island is grown adopts it (island/Island.qml).
//
// Keys: h/l or ←/→ switch tabs while the island itself has focus (not in a
// text field), Ctrl+Tab / Ctrl+Shift+Tab anywhere (plain Tab moves the run
// list), Esc collapses.
import QtQuick
import quickshell
import "../state"
import "../components"
import "tabs"
import "routes.js" as Routes

FocusScope {
    id: panel

    implicitHeight: col.implicitHeight
    // the tab area's cap, set by the Island adopting this (70% of its screen)
    property real maxHeight: 700

    readonly property var tabs: [systemTab, calendarTab, notificationsTab, networkTab, runTab, clipboardTab]
    readonly property Item current: tabs.find(t => t.shown) || null
    // run/clipboard, or a tab that's in a text field right now
    readonly property bool needsKeyboard: IslandState.wantsKeyboard || (current !== null && current.needsKeyboard)

    function focusCurrent() {
        if (current && current.initialFocus) current.initialFocus.forceActiveFocus()
        else keys.forceActiveFocus()
    }

    Connections {
        target: IslandState
        function onTabChanged() { if (IslandState.grown) Qt.callLater(panel.focusCurrent) }
        function onPanelFocusRequested() { keys.forceActiveFocus() }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_H || event.key === Qt.Key_Left) IslandState.step(-1)
            else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) IslandState.step(1)
            else if (event.key === Qt.Key_Escape) IslandState.close()
            else return
            event.accepted = true
        }
    }

    Shortcut {
        sequences: ["Ctrl+Tab"]
        enabled: IslandState.grown
        onActivated: IslandState.step(1)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]
        enabled: IslandState.grown
        onActivated: IslandState.step(-1)
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        // system │ calendar │ notifications 3 │ …, the open one inverted
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Repeater {
                model: Routes.TABS

                delegate: Row {
                    required property string modelData
                    required property int index
                    readonly property bool open: IslandState.tab === modelData

                    MonoText {
                        visible: index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 6
                        rightPadding: 6
                        color: Colors.dim
                        text: "│"
                    }

                    Rectangle {
                        width: label.implicitWidth + 12
                        height: 20
                        color: open ? Colors.neon : "transparent"

                        MonoText {
                            id: label
                            anchors.centerIn: parent
                            font.bold: open
                            color: open ? Colors.black : tabMouse.containsMouse ? Colors.fg : Colors.gray2
                            text: modelData === "notifications" && NotificationState.notifications.length
                                ? modelData + " " + NotificationState.notifications.length : modelData
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: IslandState.open(modelData, IslandState.screen)
                        }
                    }
                }
            }
        }

        Divider {}

        // the open tab, scrolling past maxHeight
        Flickable {
            width: parent.width
            height: Math.min(content.implicitHeight, panel.maxHeight)
            contentHeight: content.implicitHeight
            interactive: contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: content
                width: parent.width
                implicitHeight: panel.current ? panel.current.implicitHeight : 0

                SystemTab { id: systemTab; width: parent.width }
                CalendarTab { id: calendarTab; width: parent.width }
                NotificationsTab { id: notificationsTab; width: parent.width }
                NetworkTab { id: networkTab; width: parent.width }
                RunTab { id: runTab; width: parent.width }
                ClipboardTab { id: clipboardTab; width: parent.width }
            }
        }
    }
}
