// Data for the command center's `!` (tools) mode: capture (screenshots,
// recording, color picker), clipboard history and notifications. Clipboard
// entries load when their page opens; like popups/ClipboardMenu.qml, only
// entry ids ever go on a command line, since previews can hold passwords.
import Quickshell
import Quickshell.Io
import QtQuick
import "../../state"

Item {
    id: root

    readonly property string name: "tools"
    readonly property string glyph: "\u{f8cd}"   // build
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    // Asks the command center to open another popup and get out of the way.
    signal openPopup(string popup)

    property var clips: []     // [{id, preview}], newest first

    readonly property var rows: [
        { kind: "header", title: "capture" },
        { kind: "action", group: "capture", key: "tool:shot-region", title: "screenshot region",
          glyph: "\u{ec08}", aliases: "screenshot capture crop satty print",
          subtitle: "freeze, crop, annotate · $mod+shift+s",
          run: () => Quickshell.execDetached([bin + "screenshot-region"]) },
        { kind: "toggle", group: "capture", key: "tool:record", title: "record screen",
          glyph: "\u{f679}", aliases: "recording video capture screenrec",
          on: () => RecorderState.recording,
          subtitle: () => RecorderState.recording ? "recording · " + RecorderState.elapsedText() : "window, region or monitor · $mod+shift+r",
          run: () => RecorderState.recording ? RecorderState.stop() : Quickshell.execDetached([bin + "screenrec"]) },
        { kind: "action", group: "capture", key: "tool:color", title: "color picker",
          glyph: "\u{e3b8}", aliases: "pick colour hex eyedropper",
          subtitle: "click a pixel, #hex to the clipboard",
          run: () => Quickshell.execDetached([bin + "color-pick"]) },
        { kind: "action", group: "capture", key: "tool:captures", title: "captures folder",
          glyph: "\u{e04a}", aliases: "screenshots recordings videos",
          subtitle: "~/Videos/Captures",
          run: () => Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/Videos/Captures"]) },
        { kind: "header", title: "clipboard" },
        { kind: "page", group: "clipboard", key: "tool:clipboard", title: "clipboard history",
          glyph: "\u{e14f}", aliases: "cliphist paste copy",
          subtitle: "enter copies back · $mod+v",
          enter: () => clipProc.running = true,
          rows: () => clipRows() },
        { kind: "header", title: "notifications" },
        { kind: "action", group: "notifications", key: "tool:notifications", title: "notification history",
          glyph: "\u{e7f5}", aliases: "notifications unread",
          subtitle: () => NotificationState.notifications.length + " unread",
          run: () => root.openPopup("calendar") },
        { kind: "toggle", group: "notifications", key: "tool:silence", title: "silence",
          glyph: "\u{e7f6}", aliases: "dnd do not disturb quiet",
          on: () => NotificationState.dnd, subtitle: () => NotificationState.dnd ? "toasts hidden" : "off",
          run: () => NotificationState.toggleDnd() },
    ]

    function clipRows() {
        if (!clips.length) return [{ kind: "info", title: clipProc.running ? "loading…" : "clipboard history is empty" }]
        return clips.map(c => ({
            kind: "action", group: "clipboard", title: c.preview.replace(/\s+/g, " "),
            glyph: "\u{e14f}",   // content_paste
            run: () => Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist decode | wl-copy", "sh", c.id]),
        }))
    }

    Process {
        id: clipProc
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -n 100"]
        stdout: StdioCollector {
            onStreamFinished: root.clips = text.split("\n").filter(l => l).map(l => {
                const tab = l.indexOf("\t")
                return { id: l.slice(0, tab), preview: l.slice(tab + 1) }
            })
        }
    }
}
