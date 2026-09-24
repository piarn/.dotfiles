// Whether ~/.local/bin/screenrec is recording, for the bar's REC
// indicator. The script keeps "<pid> <start epoch>" in
// $XDG_RUNTIME_DIR/screenrec.state while recording and empties it when
// done; this just watches that file.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property var fields: file.text().trim().split(/\s+/)
    readonly property int pid: parseInt(fields[0]) || 0
    readonly property int startedAt: parseInt(fields[1]) || 0
    readonly property bool recording: pid > 0
    property int elapsed: 0   // seconds

    function elapsedText() {
        const m = Math.floor(elapsed / 60), s = elapsed % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // SIGINT, like the script's own stop, so wf-recorder finalises the mp4.
    function stop() {
        if (recording) Quickshell.execDetached(["kill", "-INT", String(pid)])
    }

    FileView {
        id: file
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/screenrec.state"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        triggeredOnStart: true
        onTriggered: root.elapsed = Math.max(0, Math.floor(Date.now() / 1000) - root.startedAt)
    }
}
