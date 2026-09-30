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

    readonly property var tabs: [systemTab, calendarTab, notificationsTab, networkTab, themesTab, runTab, clipboardTab]
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

        // one square per tab, the open one filled like the focused
        // workspace in the strip; the name (of the hovered tab, else the
        // open one) beside them
        Item {
            width: parent.width
            height: 24

            Row {
                id: tabRow
                // the icons alone are centered, so they never shift as the name
                // beside them changes length
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                property string hovered: ""

                Repeater {
                    model: Routes.TABS

                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool open: IslandState.tab === modelData
                        readonly property var glyphs: ({
                            system: "\u{e429}",          // tune
                            calendar: "\u{ebcc}",        // calendar_month
                            notifications: "\u{e7f4}",   // notifications
                            network: "\u{e63e}",         // wifi
                            themes: "\u{e3b7}",          // palette
                            run: "\u{e8b6}",             // search
                            clipboard: "\u{e14f}"        // content_paste
                        })
                        width: 24
                        height: 24
                        color: open ? Colors.neon : tabMouse.containsMouse ? Colors.surface : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            font.pixelSize: 16
                            color: parent.open ? Colors.black
                                : modelData === "notifications" && NotificationState.notifications.length ? Colors.acid
                                : tabMouse.containsMouse ? Colors.fg : Colors.gray2
                            text: parent.glyphs[modelData]
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: tabRow.hovered = containsMouse ? modelData : (tabRow.hovered === modelData ? "" : tabRow.hovered)
                            onClicked: IslandState.open(modelData, IslandState.screen)
                        }
                    }
                }

            }

            MonoText {
                anchors.left: tabRow.right
                anchors.verticalCenter: tabRow.verticalCenter
                leftPadding: 10
                color: tabRow.hovered ? Colors.fg : Colors.gray2
                text: {
                    const t = tabRow.hovered || IslandState.tab
                    return t === "notifications" && NotificationState.notifications.length
                        ? t + " · " + NotificationState.notifications.length : t
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
                ThemesTab { id: themesTab; width: parent.width }
                RunTab { id: runTab; width: parent.width }
                ClipboardTab { id: clipboardTab; width: parent.width }
            }
        }
    }
}
