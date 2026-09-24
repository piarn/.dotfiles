// Network popup, opened by clicking the network widget in Bar.qml. Three
// sections:
//  - interfaces: every managed ethernet/wifi/wwan device, with the one
//    holding the default route marked primary, [make primary] on the rest,
//    and connect/disconnect per device
//  - vpn: NetworkManager vpn/wireguard profiles (hidden when there are none)
//  - wi-fi: nearby networks, click to connect; asks for a password up front
//    for secured networks with no saved profile instead of failing first
// Enterprise (802.1X) networks take a username + password (PEAP/MSCHAPv2),
// and [hidden] joins a network that doesn't broadcast its SSID. Anything
// deeper (static IPs, DNS, certificates, WEP) goes to [settings], which
// opens nm-connection-editor.
import QtQuick
import quickshell
import "../state"
import "../components"

BarPopup {
    id: menu
    name: "network"
    fixedWidth: 400

    property string lastAttempted: ""
    // Network whose credentials form is open: a wifiNetworks entry, or
    // {hidden: true} for [hidden].
    property var pwNet: null
    readonly property bool credsOpen: pwNet !== null
    readonly property bool credsHidden: credsOpen && !!pwNet.hidden
    readonly property bool credsEnterprise: credsOpen && /802\.1X/.test(pwNet.security || "")
    // exclusive keyboard while typing credentials or searching, see CardWindow
    needsKeyboard: credsOpen || searching
    property bool searching: false

    readonly property var shownNetworks: {
        if (!NetworkState.wifiEnabled) return []
        const words = searchInput.text.toLowerCase().split(/\s+/).filter(w => w)
        if (!words.length) return NetworkState.wifiNetworks
        return NetworkState.wifiNetworks.filter(n => {
            const ssid = n.ssid.toLowerCase()
            return words.every(w => ssid.includes(w))
        })
    }

    function stopSearch() {
        searching = false
        focusCatcher()
    }

    readonly property int routedCount: NetworkState.devices.filter(d => d.connected && d.gateway).length

    function clickNetwork(net) {
        if (net.active) return
        // WEP needs more than a password field.
        if (!net.known && /WEP/.test(net.security)) {
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

    function openHidden() {
        pwNet = { hidden: true, ssid: "", security: "" }
    }

    function submitCredentials() {
        if (!pwNet) return
        const password = pwField.text
        const identity = credsEnterprise ? userField.text.trim() : ""
        const net = credsHidden ? { hidden: true, ssid: ssidField.text.trim(), security: "" } : pwNet
        // hidden: SSID required, password optional (open network)
        if (!net.ssid || (credsEnterprise && !identity) || (!credsHidden && !password)) return
        lastAttempted = net.ssid
        pwNet = null
        NetworkState.connectWifi(net, password, identity)
    }

    function cancelPassword() {
        pwNet = null
        if (searching) searchInput.forceActiveFocus()
        else focusCatcher()
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

    onPwNetChanged: {
        ssidField.text = ""
        userField.text = ""
        pwField.text = ""
        if (!pwNet) return
        const first = credsHidden ? ssidField : credsEnterprise ? userField : pwField
        Qt.callLater(() => first.input.forceActiveFocus())
    }

    onOpened: {
        pwNet = null
        searching = false
        searchInput.text = ""
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
                if (net && net.security && !/WEP/.test(net.security)) menu.pwNet = net
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

        MonoText {
            anchors.left: parent.left
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

        MonoText {
            visible: NetworkState.devices.length === 0
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

                Icon {
                    id: devIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
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

                        MonoText {
                            id: devTitle
                            anchors.left: parent.left
                            width: Math.min(implicitWidth, parent.width - devName.implicitWidth - devActions.implicitWidth - 16)
                            font.pixelSize: 13
                            font.bold: devRow.modelData.primary
                            elide: Text.ElideRight
                            color: devRow.modelData.connected ? Colors.fg : Colors.gray2
                            text: menu.deviceTitle(devRow.modelData)
                        }
                        MonoText {
                            id: devName
                            anchors.left: devTitle.right
                            anchors.leftMargin: 6
                            anchors.baseline: devTitle.baseline
                            font.pixelSize: 11
                            color: Colors.gray
                            text: devRow.modelData.device
                        }

                        Row {
                            id: devActions
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            MonoText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: devRow.modelData.primary && menu.routedCount > 1
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

                    MonoText {
                        width: parent.width
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

        MonoText {
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

                    Icon {
                        color: vpnRow.modelData.active ? Colors.neon : Colors.gray
                        text: "\u{f0582}"
                    }
                    MonoText {
                        width: parent.width - 30
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

            MonoText {
                anchors.left: parent.left
                color: Colors.gray
                text: !NetworkState.wifiEnabled ? "wi-fi is off"
                    : NetworkState.scanning ? "wi-fi · scanning…" : "wi-fi networks"
            }
            Row {
                anchors.right: parent.right
                spacing: 10
                visible: NetworkState.wifiEnabled

                TextButton {
                    label: "hidden"
                    baseColor: Colors.gray2
                    onClicked: menu.openHidden()
                }
                TextButton {
                    id: rescanBtn
                    label: "rescan"
                    enabled: !NetworkState.scanning
                    onClicked: NetworkState.scan()
                }
            }
        }

        // Search, for places with a lot of networks (offices broadcast
        // hundreds): space-separated words, all must appear in the SSID.
        Rectangle {
            width: parent.width
            height: 24
            visible: NetworkState.wifiEnabled
            radius: 3
            color: Colors.surface
            border.color: searchInput.activeFocus ? Colors.neon : Colors.dim
            border.width: 1

            Icon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 12
                color: Colors.gray
                text: "\u{f002}"
            }

            TextInput {
                id: searchInput
                anchors.left: searchIcon.right
                anchors.right: clearSearch.left
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                font.family: "monospace"
                font.pixelSize: 12
                color: Colors.fg
                clip: true
                onActiveFocusChanged: if (activeFocus) menu.searching = true
                onTextChanged: netList.keptY = 0
                Keys.onEscapePressed: {
                    if (text !== "") text = ""
                    else menu.stopSearch()
                }
                // Enter picks the top match.
                Keys.onReturnPressed: if (menu.shownNetworks.length) menu.clickNetwork(menu.shownNetworks[0])
                Keys.onEnterPressed: if (menu.shownNetworks.length) menu.clickNetwork(menu.shownNetworks[0])
            }

            MonoText {
                anchors.left: searchInput.left
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text === ""
                color: Colors.gray
                text: "search " + NetworkState.wifiNetworks.length + " networks"
            }

            Icon {
                id: clearSearch
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text !== ""
                width: visible ? implicitWidth : 0
                font.pixelSize: 12
                color: clearMouse.containsMouse ? Colors.fg : Colors.gray
                text: "\u{f00d}"

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: searchInput.text = ""
                }
            }
        }

        MonoText {
            visible: NetworkState.wifiEnabled && searchInput.text !== "" && menu.shownNetworks.length === 0
            leftPadding: 8
            color: Colors.gray
            text: "no networks match"
        }

        // ListView rather than a Repeater: with hundreds of networks only
        // the visible rows get built. Scrolls past 8 rows (28px + 2px
        // spacing) so the popup never runs off the screen.
        ListView {
            id: netList
            width: parent.width
            height: Math.min(contentHeight, 8 * 30)
            visible: count > 0
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            model: menu.shownNetworks

            // A new model (every poll where anything changed) jumps a
            // ListView back to the top; keep the scroll position instead.
            property real keptY: 0
            onContentYChanged: if (moving || dragging) keptY = contentY
            onMovementEnded: keptY = contentY
            onModelChanged: Qt.callLater(() => { netList.contentY = Math.min(netList.keptY, Math.max(0, netList.contentHeight - netList.height)) })

            delegate: Rectangle {
                id: netRow
                required property var modelData
                width: ListView.view.width
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

                Icon {
                    id: netIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    color: netRow.modelData.active ? Colors.neon : Colors.gray2
                    text: NetworkState.wifiGlyph(netRow.modelData.signal)
                }

                MonoText {
                    anchors.left: netIcon.right
                    anchors.right: netRight.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
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
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                        color: Colors.gray2
                        text: netRow.modelData.security ? "\u{f033e}" : ""
                    }
                    MonoText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        horizontalAlignment: Text.AlignRight
                        font.pixelSize: 11
                        color: Colors.gray2
                        text: netRow.modelData.signal + "%"
                    }
                }
            }

            Rectangle {
                visible: netList.interactive
                parent: netList
                x: netList.width - width
                y: netList.visibleArea.yPosition * netList.height
                width: 3
                height: netList.visibleArea.heightRatio * netList.height
                radius: 1.5
                color: Colors.gray
            }
        }

        // Outside the Repeater on purpose: wifiNetworks is replaced on
        // every refresh, which rebuilds the delegates and would wipe a
        // half-typed password (and its focus) if the input lived there.
        Column {
            visible: menu.credsOpen
            width: parent.width
            leftPadding: 8
            topPadding: 4
            spacing: 6

            MonoText {
                font.pixelSize: 11
                color: Colors.gray2
                text: menu.credsHidden ? "join a hidden network (no password = open)"
                    : menu.credsEnterprise ? "sign in to " + (menu.pwNet ? menu.pwNet.ssid : "") + " (PEAP)"
                    : "password for " + (menu.pwNet ? menu.pwNet.ssid : "")
            }

            InputField {
                id: ssidField
                visible: menu.credsHidden
                placeholder: "network name (SSID)"
                input.KeyNavigation.tab: pwField.input
                onAccepted: menu.submitCredentials()
                onEscaped: menu.cancelPassword()
            }
            InputField {
                id: userField
                visible: menu.credsEnterprise
                placeholder: "username"
                input.KeyNavigation.tab: pwField.input
                onAccepted: menu.submitCredentials()
                onEscaped: menu.cancelPassword()
            }

            Row {
                spacing: 8

                InputField {
                    id: pwField
                    placeholder: "password"
                    password: true
                    onAccepted: menu.submitCredentials()
                    onEscaped: menu.cancelPassword()
                }
                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "connect"
                    onClicked: menu.submitCredentials()
                }
                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "cancel"
                    baseColor: Colors.gray2
                    onClicked: menu.cancelPassword()
                }
            }
        }
    }

    MonoText {
        width: parent.width
        visible: NetworkState.actionStatus !== ""
        color: NetworkState.actionStatus.startsWith("failed") || NetworkState.actionStatus.startsWith("busy")
            ? Colors.red : Colors.acid
        text: NetworkState.actionStatus
        wrapMode: Text.Wrap
    }
}
