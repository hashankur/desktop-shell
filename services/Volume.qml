pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property bool available: audio !== null
    readonly property real volume: audio ? Math.max(0, Math.min(1, audio.volume)) : 0
    readonly property bool muted: audio ? audio.muted : false

    function setVolume(value) {
        if (audio)
            audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute() {
        if (audio)
            audio.muted = !audio.muted;
    }
}
