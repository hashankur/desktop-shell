import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

import qs.components
import qs.services

Scope {
    id: root

    // Bind the pipewire node so its volume will be tracked
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null

        function onVolumeChanged() {
            volumeOsd.shouldShow = true;
        }

        function onMutedChanged() {
            volumeOsd.shouldShow = true;
        }
    }

    // Volume OSD
    GenericOsd {
        id: volumeOsd
        iconPath: {
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
        value: Pipewire.defaultAudioSink?.audio.volume ?? 0
    }

    // Brightness OSD
    GenericOsd {
        id: brightnessOsd
        iconPath: Quickshell.iconPath("display-brightness-symbolic")
        value: Brightness.brightness

        Connections {
            target: Brightness

            function onBrightnessTriggered() {
                brightnessOsd.shouldShow = true;
            }
        }
    }
}
