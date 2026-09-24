// Network popup, opened by clicking the network widget in Bar.qml. Three
// sections:
//  - interfaces: every managed ethernet/wifi/wwan device, with the one
//    holding the default route marked primary, [make primary] on the rest,
//    and connect/disconnect per device
//  - vpn: NetworkManager vpn/wireguard profiles (hidden when there are none)
//  - wi-fi: nearby networks, click to connect; asks for a password up front
//    for secured networks with no saved profile instead of failing first
// Anything deeper (static IPs, DNS, 802.1X) goes to [settings], which opens
// nm-connection-editor.
import QtQuick
import quickshell
import "../state"
import "../components"

BarPopup {
    id: menu
    name: "network"
    fixedWidth: 400

    property string lastAttempted: ""
    property var pwNet: null   // network whose password row is open
    readonly property string pwFor: pwNet ? pwNet.ssid : ""
    // exclusive keyboard while typing a password, see CardWindow
    needsKeyboard: pwFor !== ""

    readonly property int routedCount: NetworkState.devices.filter(d => d.connected && d.gateway).length

    function clickNetwork(net) {
        if (net.active) return
        // Enterprise (802.1X) and WEP need more than a password field.
        if (!net.known && /802\.1X|WEP/.test(net.security)) {
            NetworkState.openEditor()
            close()
            return
        }
        if (net.security && !net.known) {
            pwNet = net
            return
        }
        pwNet = null
        lastAttempted = net.ssid
        NetworkState.connectWifi(net)
    }

    function submitPassword(password) {
        if (!password || !pwNet) return
        const net = pwNet
        lastAttempted = net.ssid
        pwNet = null
        NetworkState.connectWifi(net, password)
    }

    function cancelPassword() {
        pwNet = null
        focusCatcher()
    }

    function deviceTitle(dev) {
        if (dev.type === "wifi") return dev.connection || "Wi-Fi"
        if (dev.type === "wwan") return dev.connection || "Mobile"
        // netplan-generated profile names are just a uuid — not worth showing
        return dev.connection && !dev.connection.startsWith("netplan-") ? dev.connection : "Ethernet"
    }

    function deviceDetail(dev) {
        if (dev.connected) {
            const parts = [dev.ip || "no ip"]
            if (dev.type === "wifi") parts.unshift(dev.signal + "%")
            if (dev.gateway) parts.push("via " + dev.gateway, "metric " + dev.metric)
            return parts.join(" · ")
        }
        if (dev.state === "unavailable") return dev.type === "ethernet" ? "cable unplugged" : "unavailable"
        return dev.state
    }

    onPwForChanged: {
        pwInput.text = ""
        if (pwFor) Qt.callLater(() => pwInput.forceActiveFocus())
    }

    onOpened: {
        pwNet = null
        NetworkState.actionStatus = ""
        NetworkState.refresh()
        NetworkState.scan()
    }

    // A failed connect to a secured network most often means a wrong or
    // missing password — reopen the password row for it.
    Connections {
        target: NetworkState
        function onActionStatusChanged() {
            if (NetworkState.actionStatus.startsWith("failed") && menu.lastAttempted) {
                const net = NetworkState.wifiNetworks.find(n => n.ssid === menu.lastAttempted)
                if (net && net.security && !/802\.1X|WEP/.test(net.security)) menu.pwNet = net
                menu.lastAttempted = ""
            } else if (NetworkState.actionStatus === "") {
                menu.lastAttempted = ""
            }
        }
    }

    // header
    Item {
        width: parent.width
        height: settingsBtn.implicitHeight

        Text {
            anchors.left: parent.left
            font.family: "monospace"
            font.pixelSize: 12
            color: Colors.gray
            text: "interfaces"
        }

        Row {
            anchors.right: parent.right
            spacing: 10

            TextButton {
                label: NetworkState.wifiEnabled ? "turn wi-fi off" : "turn wi-fi on"
                visible: NetworkState.wifiDevice !== null || !NetworkState.wifiEnabled
                baseColor: NetworkState.wifiEnabled ? Colors.acid : Colors.red
                enabled: !NetworkState.busy
                onClicked: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
            }
            TextButton {
                id: settingsBtn
                label: "settings"
                onClicked: {
                    NetworkState.openEditor()
                    menu.close()
                }
            }
        }
    }

    // interfaces
    Column {
        width: parent.width
        spacing: 4

        Text {
            visible: NetworkState.devices.length === 0
            font.family: "monospace"
            font.pixelSize: 12
            color: Colors.gray
            text: "no network devices"
        }

        Repeater {
            model: NetworkState.devices

            delegate: Rectangle {
                id: devRow
                required property var modelData
                readonly property bool usable: modelData.state !== "unavailable"
                width: menu.innerWidth
                height: devCol.implicitHeight + 10
                radius: 4
                color: modelData.primary ? Colors.dim : modelData.connected ? Colors.surface : "transparent"
                border.width: modelData.primary ? 1 : 0
                border.color: Colors.neon

                Text {
                    id: devIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: 16
                    color: !devRow.modelData.connected ? Colors.gray
                        : devRow.modelData.primary ? Colors.neon : Colors.acid
                    text: NetworkState.icon(devRow.modelData)
                }

                Column {
                    id: devCol
                    anchors.left: devIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Item {
                        width: parent.width
                        height: devTitle.implicitHeight

                        Text {
                            id: devTitle
                            anchors.left: parent.left
                            width: Math.min(implicitWidth, parent.width - devName.implicitWidth - devActions.implicitWidth - 16)
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: devRow.modelData.primary
                            elide: Text.ElideRight
                            color: devRow.modelData.connected ? Colors.fg : Colors.gray2
                            text: menu.deviceTitle(devRow.modelData)
                        }
                        Text {
                            id: devName
                            anchors.left: devTitle.right
                            anchors.leftMargin: 6
                            anchors.baseline: devTitle.baseline
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: Colors.gray
                            text: devRow.modelData.device
                        }

                        Row {
                            id: devActions
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: devRow.modelData.primary && menu.routedCount > 1
                                font.family: "monospace"
                                font.pixelSize: 11
                                font.bold: true
                                color: Colors.neon
                                text: "\u2605 primary"
                            }
                            TextButton {
                                visible: devRow.modelData.connected && !devRow.modelData.primary && devRow.modelData.gateway !== ""
                                label: "make primary"
                                enabled: !NetworkState.busy
                                onClicked: NetworkState.setPrimary(devRow.modelData)
                            }
                            TextButton {
                                visible: devRow.usable
                                label: devRow.modelData.connected ? "disconnect" : "connect"
                                baseColor: devRow.modelData.connected ? Colors.gray2 : Colors.acid
                                enabled: !NetworkState.busy
                                onClicked: NetworkState.toggleDevice(devRow.modelData)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        font.family: "monospace"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        color: devRow.modelData.connected ? Colors.gray2 : Colors.gray
                        text: menu.deviceDetail(devRow.modelData)
                    }
                }
            }
        }
    }

    // vpn
    Rectangle { width: parent.width; height: 1; color: Colors.dim; visible: vpnCol.visible }

    Column {
        id: vpnCol
        width: parent.width
        spacing: 4
        visible: NetworkState.vpns.length > 0

        Text {
            font.family: "monospace"
            font.pixelSize: 12
            color: Colors.gray
            text: "vpn"
        }

        Repeater {
            model: NetworkState.vpns

            delegate: Item {
                id: vpnRow
                required property var modelData
                width: menu.innerWidth
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.right: vpnBtn.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                        color: vpnRow.modelData.active ? Colors.neon : Colors.gray
                        text: "\u{f0582}"
                    }
                    Text {
                        width: parent.width - 30
                        font.family: "monospace"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        color: vpnRow.modelData.active ? Colors.fg : Colors.gray2
                        text: vpnRow.modelData.name + "  " + vpnRow.modelData.type
                    }
                }

                TextButton {
                    id: vpnBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    label: vpnRow.modelData.active ? "disconnect" : "connect"
                    baseColor: vpnRow.modelData.active ? Colors.gray2 : Colors.acid
                    enabled: !NetworkState.busy
                    onClicked: NetworkState.toggleVpn(vpnRow.modelData)
                }
            }
        }
    }

    // wi-fi
    Rectangle { width: parent.width; height: 1; color: Colors.dim; visible: wifiCol.visible }

    Column {
        id: wifiCol
        width: parent.width
        spacing: 2
        visible: NetworkState.wifiDevice !== null

        Item {
            width: parent.width
            height: rescanBtn.implicitHeight + 4

            Text {
                anchors.left: parent.left
                font.family: "monospace"
                font.pixelSize: 12
                color: Colors.gray
                text: !NetworkState.wifiEnabled ? "wi-fi is off"
                    : NetworkState.scanning ? "wi-fi · scanning…" : "wi-fi networks"
            }
            TextButton {
                id: rescanBtn
                anchors.right: parent.right
                visible: NetworkState.wifiEnabled
                label: "rescan"
                enabled: !NetworkState.scanning
                onClicked: NetworkState.scan()
            }
        }

        Repeater {
            model: NetworkState.wifiEnabled ? NetworkState.wifiNetworks : []

            delegate: Column {
                id: netRow
                required property var modelData
                width: menu.innerWidth
                spacing: 4

                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 4
                    color: netRow.modelData.active ? Colors.dim
                        : netMouse.containsMouse ? Colors.surface : "transparent"

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: netRow.modelData.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: menu.clickNetwork(netRow.modelData)
                    }

                    Text {
                        id: netIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        font.family: "Symbols Nerd Font Mono"
                        font.pixelSize: 15
                        color: netRow.modelData.active ? Colors.neon : Colors.gray2
                        text: NetworkState.wifiGlyph(netRow.modelData.signal)
                    }

                    Text {
                        anchors.left: netIcon.right
                        anchors.right: netRight.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: "monospace"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        color: netRow.modelData.active ? Colors.neon : Colors.fg
                        text: netRow.modelData.ssid
                    }

                    Row {
                        id: netRight
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // only saved networks have something to forget,
                        // so this doubles as the "saved" marker
                        TextButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: netRow.modelData.known
                            label: "forget"
                            baseColor: Colors.gray
                            enabled: !NetworkState.busy
                            onClicked: NetworkState.forgetWifi(netRow.modelData.ssid)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "Symbols Nerd Font Mono"
                            font.pixelSize: 12
                            color: Colors.gray2
                            text: netRow.modelData.security ? "\u{f033e}" : ""
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            horizontalAlignment: Text.AlignRight
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: Colors.gray2
                            text: netRow.modelData.signal + "%"
                        }
                    }
                }
            }
        }

        // Outside the Repeater on purpose: wifiNetworks is replaced on
        // every refresh, which rebuilds the delegates and would wipe a
        // half-typed password (and its focus) if the input lived there.
        Text {
            visible: menu.pwFor !== ""
            leftPadding: 8
            topPadding: 4
            font.family: "monospace"
            font.pixelSize: 11
            color: Colors.gray2
            text: "password for " + menu.pwFor
        }

        Row {
            visible: menu.pwFor !== ""
            leftPadding: 8
            spacing: 8

            Rectangle {
                width: 200
                height: 24
                radius: 3
                color: Colors.surface
                border.color: pwInput.activeFocus ? Colors.neon : Colors.dim
                border.width: 1

                TextInput {
                    id: pwInput
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.fg
                    clip: true
                    echoMode: TextInput.Password
                    Keys.onReturnPressed: menu.submitPassword(text)
                    Keys.onEnterPressed: menu.submitPassword(text)
                    Keys.onEscapePressed: menu.cancelPassword()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pwInput.text === ""
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.gray
                    text: "password"
                }
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "connect"
                onClicked: menu.submitPassword(pwInput.text)
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "cancel"
                baseColor: Colors.gray2
                onClicked: menu.cancelPassword()
            }
        }
    }

    Text {
        width: parent.width
        visible: NetworkState.actionStatus !== ""
        font.family: "monospace"
        font.pixelSize: 12
        color: NetworkState.actionStatus.startsWith("failed") || NetworkState.actionStatus.startsWith("busy")
            ? Colors.red : Colors.acid
        text: NetworkState.actionStatus
        wrapMode: Text.Wrap
    }
}
