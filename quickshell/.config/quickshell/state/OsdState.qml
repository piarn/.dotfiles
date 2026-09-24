// What the volume/brightness OSD (popups/Osd.qml) is showing. Volume and
// mic mute are picked up from Pipewire directly, so they show no matter
// what changed them (keys via wpctl, scrolling the bar icon, another app).
// Brightness has no change signal to watch, so BrightnessState calls
// show() itself.
pragma Singleton
import QtQuick

Item {
    id: root

    property string kind: ""   // "volume" | "mic" | "brightness"
    property real value: 0
    property bool muted: false
    property bool shown: false
    property var screen: null

    function show(k, v, m) {
        if (!shown) screen = PopupState.focusedScreen
        kind = k
        value = v
        muted = m
        shown = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    // Pipewire reports the initial volume of a (new) default device as a
    // change — don't flash the OSD at startup or when switching outputs.
    property bool armed: false
    Timer {
        id: arm
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }
    function disarm() {
        armed = false
        arm.restart()
    }

    // The slider in these popups already shows the level.
    function suppressed() {
        return !armed || PopupState.isOpen("volume") || PopupState.isOpen("mic") || PopupState.isOpen("quicksettings")
    }

    Connections {
        target: VolumeState
        function onSinkAudioChanged() { root.disarm() }
        function onSourceAudioChanged() { root.disarm() }
    }

    Connections {
        target: VolumeState.sinkAudio
        function onVolumeChanged() { if (!root.suppressed()) root.show("volume", VolumeState.sinkAudio.volume, VolumeState.sinkAudio.muted) }
        function onMutedChanged() { if (!root.suppressed()) root.show("volume", VolumeState.sinkAudio.volume, VolumeState.sinkAudio.muted) }
    }

    Connections {
        target: VolumeState.sourceAudio
        function onMutedChanged() { if (!root.suppressed()) root.show("mic", VolumeState.sourceAudio.volume, VolumeState.sourceAudio.muted) }
    }
}
