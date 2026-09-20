// Speaker + mic status, backed directly by Quickshell.Services.Pipewire
// (no shelling out needed here — unlike Network/Bluetooth, this module's
// reactive properties just work). PwObjectTracker is what makes
// Pipewire.defaultAudioSink/-Source's .audio properties live instead of
// stale — it needs to exist somewhere in the loaded scene, so it lives
// here rather than being duplicated in Bar.qml and both popups.
pragma Singleton
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root

    property bool volumeMenuOpen: false
    property bool micMenuOpen: false

    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var sourceAudio: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    function speakerIcon() {
        if (!root.sinkAudio) return "\u{f0581}"
        if (root.sinkAudio.muted) return "\u{f075f}"
        const v = root.sinkAudio.volume
        if (v <= 0) return "\u{f0581}"
        if (v < 0.34) return "\u{f057f}"
        if (v < 0.67) return "\u{f0580}"
        return "\u{f057e}"
    }

    function micIcon() {
        if (!root.sourceAudio) return "\u{f036d}"
        return root.sourceAudio.muted ? "\u{f036d}" : "\u{f036c}"
    }

    function adjustVolume(delta) {
        if (!root.sinkAudio) return
        root.sinkAudio.volume = Math.max(0, Math.min(1.5, root.sinkAudio.volume + delta))
    }

    function adjustMicVolume(delta) {
        if (!root.sourceAudio) return
        root.sourceAudio.volume = Math.max(0, Math.min(1.5, root.sourceAudio.volume + delta))
    }
}
