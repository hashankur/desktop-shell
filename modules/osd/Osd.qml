import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

import qs.components
import qs.services

Scope {
    id: root

    // Single shared pill: sink volume, mic volume and backlight all
    // snapshot into the same GenericOsd, so simultaneous changes can
    // never draw overlapping pills.
    GenericOsd {
        id: osd
    }

    // Bind the pipewire nodes so sink and source volumes are tracked
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    function volumeIcon() {
        const audio = Pipewire.defaultAudioSink?.audio;
        if (audio?.muted ?? false)
            return Quickshell.iconPath("audio-volume-muted-symbolic");
        const vol = audio?.volume ?? 0;
        if (vol === 0)
            return Quickshell.iconPath("audio-volume-muted-symbolic");
        if (vol < 0.34)
            return Quickshell.iconPath("audio-volume-low-symbolic");
        if (vol < 0.67)
            return Quickshell.iconPath("audio-volume-medium-symbolic");
        return Quickshell.iconPath("audio-volume-high-symbolic");
    }

    function showVolume() {
        const audio = Pipewire.defaultAudioSink?.audio;
        osd.iconPath = volumeIcon();
        osd.value = Math.max(0, Math.min(1, audio?.volume ?? 0));
        osd.trigger();
    }

    function showMic() {
        const audio = Pipewire.defaultAudioSource?.audio;
        const muted = audio?.muted ?? false;
        const vol = audio?.volume ?? 0;
        osd.iconPath = Quickshell.iconPath(muted || vol === 0 ? "audio-input-microphone-muted-symbolic" : "audio-input-microphone-symbolic");
        osd.value = Math.max(0, Math.min(1, vol));
        osd.trigger();
    }

    function showBrightness() {
        osd.iconPath = Quickshell.iconPath("display-brightness-symbolic");
        osd.value = Brightness.brightness;
        osd.trigger();
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null

        function onVolumeChanged() {
            root.showVolume();
        }

        function onMutedChanged() {
            root.showVolume();
        }
    }

    Connections {
        target: Pipewire.defaultAudioSource?.audio ?? null

        function onVolumeChanged() {
            root.showMic();
        }

        function onMutedChanged() {
            root.showMic();
        }
    }

    Connections {
        target: Brightness

        function onBrightnessTriggered() {
            root.showBrightness();
        }
    }
}
