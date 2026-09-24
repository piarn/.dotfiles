// Speaker + mic status. Reads come from Quickshell.Services.Pipewire, whose
// reactive properties just work; writes go through wpctl, same as sway's
// volume keys. Writing PwNodeAudio.volume directly was unreliable on a
// Bluetooth (a2dp) sink — a +0.06 write landed as +0.25 — so every
// slider/wheel/mute action shells out instead. PwObjectTracker is what makes
// Pipewire.defaultAudioSink/-Source's .audio properties live instead of
// stale — it needs to exist somewhere in the loaded scene, so it lives
// here rather than being duplicated in Bar.qml and both popups.
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root

    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var sourceAudio: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    // Pipewire.nodes carries every node pipewire knows about — playback
    // streams (individual apps), capture streams, and the actual hardware
    // sinks/sources. isStream filters out the former; sources additionally
    // drop each sink's ".monitor" node, which is a source in pipewire's eyes
    // but not one a person would ever want as their mic.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n =>
        !n.isSink && !n.isStream && (n.type & PwNodeType.AudioSource) && !n.name.endsWith(".monitor"))

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // Writing the "preferred" node (rather than defaultAudioSink/-Source,
    // which are read-only — they just reflect whatever the preferred one
    // resolves to) is what actually asks wireplumber to switch.
    function setSink(node) { Pipewire.preferredDefaultAudioSink = node }
    function setSource(node) { Pipewire.preferredDefaultAudioSource = node }

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

    function toggleMute(audio) {
        if (!audio) return
        const target = audio === root.sourceAudio ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@"
        Quickshell.execDetached(["wpctl", "set-mute", target, "toggle"])
    }

    // Slider drags fire far faster than wpctl runs, so each writer keeps
    // only the newest value queued. `target` remembers what was last asked
    // for until the writer goes idle, so quick wheel steps build on each
    // other instead of on a readback that hasn't caught up yet.
    function setVolume(input, v) {
        const w = input ? sourceWriter : sinkWriter
        w.target = Math.max(0, Math.min(1, v))
        const cmd = ["wpctl", "set-volume", input ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@", w.target.toFixed(4)]
        if (w.running) {
            w.pending = cmd
        } else {
            w.command = cmd
            w.running = true
        }
    }

    function adjust(input, delta) {
        const w = input ? sourceWriter : sinkWriter
        const audio = input ? root.sourceAudio : root.sinkAudio
        if (!audio) return
        setVolume(input, (w.target >= 0 ? w.target : audio.volume) + delta)
    }

    function adjustVolume(delta) { adjust(false, delta) }
    function adjustMicVolume(delta) { adjust(true, delta) }

    component VolumeWriter: Process {
        property var pending: null
        property real target: -1
        onExited: {
            if (pending) {
                command = pending
                pending = null
                running = true
            } else {
                target = -1
            }
        }
    }

    VolumeWriter { id: sinkWriter }
    VolumeWriter { id: sourceWriter }
}
