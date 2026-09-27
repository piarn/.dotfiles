// Opt-in extras: whatever ~/.dots/extras/extras.sh has stowed under
// ~/.config/quickshell/extras/<name>/. Nothing here knows about any
// particular extra — each is picked up by file name:
//  - Vpn.qml: a components/VpnProvider, created once here and listed in
//    NetworkMenu's vpn section
// Scanned once at startup; extras.sh restarts quickshell after enabling
// or disabling one, so new directories are always picked up.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Paths relative to the shell dir, e.g. "extras/mullvad/Vpn.qml".
    property var files: []
    property var vpns: []

    function vpn(name) {
        return vpns.find(v => v.name.toLowerCase() === name.toLowerCase()) || null
    }

    // Resolved from this file's own qs:/ URL, so extras share the core's
    // tree (and with it the same singletons and components).
    onFilesChanged: {
        const created = []
        for (const f of files.filter(f => f.endsWith("/Vpn.qml"))) {
            const comp = Qt.createComponent(Qt.resolvedUrl("../" + f))
            if (comp.status !== Component.Ready) {
                console.warn("extras: " + f + ": " + comp.errorString())
                continue
            }
            created.push(comp.createObject(root))
        }
        vpns = created
    }

    Process {
        running: true
        workingDirectory: Quickshell.shellDir
        command: ["sh", "-c", "[ -d extras ] && find -L extras -mindepth 2 -maxdepth 2 -name '*.qml' | sort"]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(l => l)
        }
    }
}
