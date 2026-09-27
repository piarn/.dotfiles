// Proton VPN's expanded panel in the network popup's vpn section: sign in
// while signed out, otherwise the kill switch (changeable only while
// disconnected) and a country list — click one to connect to its fastest
// server, [fastest] for the fastest anywhere.
import QtQuick
import quickshell
import "../../components"

Column {
    id: root

    required property var provider
    spacing: 6

    Component.onCompleted: if (provider.signedIn) provider.loadCountries()

    Item {
        width: parent.width
        height: signInBtn.implicitHeight
        visible: !root.provider.signedIn

        MonoText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            color: Colors.amber
            text: "signed out"
        }
        TextButton {
            id: signInBtn
            anchors.right: parent.right
            anchors.rightMargin: 8
            label: "sign in"
            onClicked: root.provider.signIn()
        }
    }

    Item {
        width: parent.width
        height: fastestBtn.implicitHeight
        visible: root.provider.signedIn

        MonoText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            color: Colors.gray
            text: "kill switch"
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            spacing: 10

            Repeater {
                model: ["off", "standard"]

                delegate: TextButton {
                    required property string modelData
                    readonly property bool current: root.provider.killSwitch === modelData
                    label: modelData
                    baseColor: current ? Colors.neon : Colors.gray2
                    // the CLI only changes it while disconnected
                    enabled: !current && !root.provider.active && !root.provider.running
                    onClicked: root.provider.setKillSwitch(modelData)
                }
            }
        }
    }

    Item {
        width: parent.width
        height: fastestBtn.implicitHeight
        visible: root.provider.signedIn

        MonoText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            color: Colors.gray
            text: root.provider.countries.length ? "countries" : "loading countries…"
        }
        TextButton {
            id: fastestBtn
            anchors.right: parent.right
            anchors.rightMargin: 8
            label: "fastest"
            enabled: !root.provider.running
            onClicked: root.provider.run("connecting to the fastest server", ["protonvpn", "connect"])
        }
    }

    // Scrolls past 8 rows (24px + 2px spacing), like the wi-fi list.
    ListView {
        id: countryList
        width: parent.width
        height: Math.min(contentHeight, 8 * 26)
        visible: root.provider.signedIn && count > 0
        spacing: 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: root.provider.countries

        delegate: Rectangle {
            id: countryRow
            required property var modelData
            readonly property bool isCurrent: root.provider.active
                && root.provider.location.endsWith(modelData.name)
            width: ListView.view.width
            height: 24
            radius: 4
            color: isCurrent ? Colors.dim : countryMouse.containsMouse ? Colors.surface : "transparent"

            MouseArea {
                id: countryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.provider.connectCountry(countryRow.modelData.code)
            }
            MonoText {
                anchors.left: parent.left
                anchors.right: countryCode.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 13
                elide: Text.ElideRight
                color: countryRow.isCurrent ? Colors.neon : Colors.fg
                text: countryRow.modelData.name
            }
            MonoText {
                id: countryCode
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 11
                color: Colors.gray
                text: countryRow.modelData.code.toLowerCase()
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
}
