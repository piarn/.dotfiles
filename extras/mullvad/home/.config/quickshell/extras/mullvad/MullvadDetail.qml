// Mullvad's expanded panel in the network tab's vpn section: relay
// location picker (click a country, or › to pick one of its cities),
// lockdown mode and auto-connect, and when the account runs out.
import QtQuick
import quickshell
import "../../components"

Column {
    id: root

    required property var provider
    spacing: 6

    // Country whose cities are expanded in the list.
    property string openCountry: ""

    // `mullvad relay get`'s "country pl" / "city pl waw" / "hostname pl waw pl-waw-wg-101"
    readonly property var selected: {
        const parts = provider.relayLocation.split(/\s+/)
        return { country: parts[1] || "", city: parts[0] !== "country" ? parts[2] || "" : "" }
    }

    Component.onCompleted: provider.loadRelays()

    Item {
        width: parent.width
        height: anyBtn.implicitHeight

        MonoText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            color: Colors.gray
            text: "location · " + (root.provider.relayLocation || "…")
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            spacing: 10

            TextButton {
                visible: root.provider.active
                label: "reconnect"
                baseColor: Colors.gray2
                onClicked: root.provider.reconnect()
            }
            TextButton {
                id: anyBtn
                visible: root.provider.relayLocation !== "any"
                label: "any"
                onClicked: root.provider.setLocation("any")
            }
        }
    }

    MonoText {
        visible: root.provider.countries.length === 0
        leftPadding: 8
        color: Colors.gray
        text: "loading relays…"
    }

    // Scrolls past 8 rows (24px + 2px spacing), like the wi-fi list.
    ListView {
        id: countryList
        width: parent.width
        height: Math.min(contentHeight, 8 * 26)
        visible: count > 0
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: root.provider.countries

        delegate: Column {
            id: countryRow
            required property var modelData
            readonly property bool isSelected: root.selected.country === modelData.code
            readonly property bool expanded: root.openCountry === modelData.code
            width: ListView.view.width
            spacing: 2

            Rectangle {
                width: parent.width
                height: 24
                radius: 4
                color: countryRow.isSelected && !root.selected.city ? Colors.dim
                    : countryMouse.containsMouse ? Colors.surface : "transparent"

                MouseArea {
                    id: countryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.provider.setLocation(countryRow.modelData.code)
                }

                MonoText {
                    anchors.left: parent.left
                    anchors.right: countryCode.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    color: countryRow.isSelected ? Colors.neon : Colors.fg
                    text: countryRow.modelData.name
                }
                MonoText {
                    id: countryCode
                    anchors.right: chevron.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 11
                    color: Colors.gray
                    text: countryRow.modelData.code
                }

                // cities
                Rectangle {
                    id: chevron
                    visible: countryRow.modelData.cities.length > 1
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 26
                    radius: 4
                    color: chevronMouse.containsMouse ? Colors.deep : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        color: Colors.gray2
                        text: countryRow.expanded ? "\u{e5ce}" : "\u{e5cf}"   // expand_less / expand_more
                    }

                    MouseArea {
                        id: chevronMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openCountry = countryRow.expanded ? "" : countryRow.modelData.code
                    }
                }
            }

            Repeater {
                model: countryRow.expanded ? countryRow.modelData.cities : []

                delegate: Rectangle {
                    id: cityRow
                    required property var modelData
                    readonly property bool isSelected: countryRow.isSelected && root.selected.city === modelData.code
                    width: countryRow.width
                    height: 22
                    radius: 4
                    color: isSelected ? Colors.dim : cityMouse.containsMouse ? Colors.surface : "transparent"

                    MouseArea {
                        id: cityMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.provider.setLocation(countryRow.modelData.code, cityRow.modelData.code)
                    }

                    MonoText {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: cityRow.isSelected ? Colors.neon : Colors.fg
                        text: cityRow.modelData.name
                    }
                    MonoText {
                        anchors.right: parent.right
                        anchors.rightMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 11
                        color: Colors.gray
                        text: cityRow.modelData.code
                    }
                }
            }
        }

        Rectangle {
            visible: countryList.interactive
            parent: countryList
            x: countryList.width - width
            y: countryList.visibleArea.yPosition * countryList.height
            width: 3
            height: countryList.visibleArea.heightRatio * countryList.height
            radius: 1.5
            color: Colors.dim
        }
    }

    Row {
        width: parent.width
        spacing: 8

        ToggleTile {
            width: (parent.width - parent.spacing) / 2
            icon: "\u{f686}"   // shield_lock
            title: "lockdown"
            subtitle: "block when off"
            active: root.provider.lockdown
            onToggled: root.provider.setLockdown(!root.provider.lockdown)
        }
        ToggleTile {
            width: (parent.width - parent.spacing) / 2
            icon: "\u{e089}"   // start
            title: "auto-connect"
            subtitle: "on startup"
            active: root.provider.autoConnect
            onToggled: root.provider.setAutoConnect(!root.provider.autoConnect)
        }
    }

    MonoText {
        visible: root.provider.expires !== null
        leftPadding: 8
        color: root.provider.daysLeft < 0 ? Colors.red : root.provider.daysLeft < 7 ? Colors.amber : Colors.gray2
        text: !root.provider.expires ? "" : root.provider.daysLeft < 0 ? "account expired"
            : "account expires " + Qt.formatDate(root.provider.expires, "yyyy-MM-dd")
              + " · " + root.provider.daysLeft + (root.provider.daysLeft === 1 ? " day" : " days")
    }
}
