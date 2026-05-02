pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: root

    property int refCount: 0  // Track active UI components for reference counting

    property real brightness: 0.0  // normalized 0.0 to 1.0
    property bool available: false

    // Signal emitted whenever brightness file changes, regardless of whether normalized value changed
    // This ensures OSD triggers even when brightness is already at max
    signal brightnessTriggered()

    // Paths for brightness control (may vary by system)
    readonly property string brightnessPath: "/sys/class/backlight/amdgpu_bl1/brightness"
    readonly property string maxBrightnessPath: "/sys/class/backlight/amdgpu_bl1/max_brightness"

    property int maxBrightness: 255
    property int prevBrightness: -1

    // Reference Counting: Only monitor when UI is visible
    function addRef() {
        refCount++;
        brightnessFile.watchChanges = refCount > 0;
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1);
        brightnessFile.watchChanges = refCount > 0;
    }

    // Read max brightness once at startup
    FileView {
        id: maxBrightnessFile
        path: root.maxBrightnessPath

        onLoaded: {
            const raw = parseInt(maxBrightnessFile.text().trim());
            if (raw > 0) {
                root.maxBrightness = raw;
                root.available = true;
                // Trigger initial brightness read
                brightnessFile.reload();
            }
        }
    }

    // Reactive brightness file watcher
    // Uses FileView's built-in watchChanges for inotify-based monitoring
    // No polling timers or external processes needed
    FileView {
        id: brightnessFile
        path: root.brightnessPath
        watchChanges: root.refCount > 0

        onLoaded: {
            const raw = parseInt(brightnessFile.text().trim());
            if (raw >= 0 && raw !== root.prevBrightness) {
                root.prevBrightness = raw;
                root.brightness = Math.max(0, Math.min(1, raw / root.maxBrightness));
            }
        }

        onFileChanged: {
            // File changed on disk, re-read it
            reload();
            // Emit trigger signal even if normalized value doesn't change
            // This ensures OSD shows even when brightness is already at max
            root.brightnessTriggered();
        }
    }

    Component.onCompleted: {
        maxBrightnessFile.reload();
    }
}
