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
    }

    // Volume OSD
    GenericOsd {
        id: volumeOsd
        iconPath: Quickshell.iconPath("audio-volume-high-symbolic")
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

        Component.onCompleted: {
            Brightness.addRef();
        }

        Component.onDestruction: {
            Brightness.removeRef();
        }
    }
}
