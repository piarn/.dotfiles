// Session lock screen, replacing swaylock. WlSessionLock speaks the same
// ext-session-lock-v1 protocol swaylock used: the compositor grabs all
// input and, per the Wayland protocol itself, keeps the screen locked and
// painted solid even if this whole quickshell process dies — there is no
// code path here that can accidentally leave the desktop exposed. PamContext
// (Quickshell.Services.Pam) does real PAM authentication against
// /etc/pam.d/quickshell-lock (installed by ~/.dots/install.sh's
// install_pam_lock_config — see that file for why it's a separate service
// rather than reusing swaylock's or login's).
//
// Triggered by `qs ipc call lock lock` — sway's $mod+Escape bind, and
// PowerMenu's own "lock" action, both just shell out to that same IPC call
// rather than referencing this file directly, same loose coupling as
// Launcher/PowerMenu's own toggles. Deliberately no Escape-to-dismiss
// keybinding anywhere in this file: unlike Launcher/PowerMenu, this is a
// security surface, so the only way out is a correct password.
//
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import quickshell

// Non-visual wrapper: WlSessionLock's own default property is `surface`
// (a single Component, not a generic child list), so the PamContext/
// IpcHandler below have to live as its siblings rather than its children —
// nesting them inside WlSessionLock silently drops them (no QML error, they
// just never get created). Item has the generic "data" default property
// that holds arbitrary children, same reason state/BluetoothState.qml's
// singleton is an Item rather than a QtObject.
Item {
    id: root

    // Shared across every screen's surface (multi-monitor: typing on one
    // output's surface should unlock all of them at once) — referenced by
    // id from inside the per-screen `surface` Component below. Direct id
    // access across a Component boundary works here the same way it does in
    // PowerMenu.qml's Repeater delegate (`powerMenu.selected`/`.run`):
    // ids resolve against the whole document, not the instantiation point.
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property string statusMessage: ""

    function tryUnlock() {
        if (currentText === "" || unlockInProgress) return
        unlockInProgress = true
        showFailure = false
        pam.start()
    }

    WlSessionLock {
        id: sessionLock

        onLockStateChanged: {
            lockFlag.setText(locked ? "1\n" : "0\n")
            if (locked) {
                root.currentText = ""
                root.showFailure = false
                root.statusMessage = ""
            }
        }

        surface: Component {
            WlSessionLockSurface {
                id: surface
                color: Colors.black

                onVisibleChanged: if (visible) Qt.callLater(() => passwordInput.forceActiveFocus())

                Column {
                    anchors.centerIn: parent
                    spacing: 28

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Text {
                            id: clock
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.fg
                            font.family: "monospace"
                            font.pixelSize: 64
                            text: {
                                void ticker.tick // re-evaluate on tick
                                const d = new Date()
                                return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
                            }

                            Timer {
                                id: ticker
                                property int tick: 0
                                running: true
                                repeat: true
                                interval: 1000
                                onTriggered: tick++
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.gray
                            font.family: "monospace"
                            font.pixelSize: 14
                            text: {
                                void ticker.tick
                                return Qt.formatDate(new Date(), "dddd, MMMM d")
                            }
                        }
                    }

                    Rectangle {
                        id: box
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 260
                        height: 42
                        color: Colors.black
                        border.color: root.showFailure ? Colors.red : (passwordInput.activeFocus ? Colors.neon : Colors.dim)
                        border.width: 1
                        radius: 4

                        SequentialAnimation {
                            id: shake
                            NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -8; duration: 40 }
                            NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 8; duration: 40 }
                            NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -6; duration: 40 }
                            NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
                        }

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.margins: 10
                            color: Colors.fg
                            font.family: "monospace"
                            font.pixelSize: 14
                            clip: true
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            enabled: !root.unlockInProgress
                            text: root.currentText
                            onTextChanged: root.currentText = text

                            Keys.onReturnPressed: root.tryUnlock()
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 16
                        color: root.showFailure ? Colors.red : Colors.amber
                        font.family: "monospace"
                        font.pixelSize: 12
                        text: root.unlockInProgress ? "verifying..." : root.statusMessage
                    }
                }

                Connections {
                    target: root
                    function onShowFailureChanged() { if (root.showFailure) shake.start() }
                    // `text: root.currentText` on passwordInput (below) only sets
                    // the *initial* value — Qt breaks that declarative binding the
                    // moment the user types a keystroke (it becomes an imperative
                    // write to `text` from then on), so resetting root.currentText
                    // alone stops reaching the field after the first character ever
                    // typed into it. Force the field back in sync explicitly instead.
                    function onCurrentTextChanged() { passwordInput.text = root.currentText }
                }
            }
        }
    }

    // Read by ~/.local/bin/qs-watchdog: if it has to kill a hung quickshell
    // while this says 1, the restarted instance locks again.
    FileView {
        id: lockFlag
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-locked"
        printErrors: false
    }

    PamContext {
        id: pam
        config: "quickshell-lock"

        onPamMessage: {
            if (responseRequired) respond(root.currentText)
            else if (message.length > 0) root.statusMessage = message
        }

        onCompleted: (result) => {
            root.unlockInProgress = false
            if (result === PamResult.Success) {
                sessionLock.locked = false
            } else {
                root.currentText = ""
                root.showFailure = true
                root.statusMessage = "wrong password"
            }
        }

        onError: (err) => {
            root.unlockInProgress = false
            root.showFailure = true
            root.statusMessage = PamError.toString(err)
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { sessionLock.locked = true }
    }
}
