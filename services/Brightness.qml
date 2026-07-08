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

    // Discovered paths (populated at startup)
    readonly property string brightnessPath: _backlightDir !== "" ? _backlightDir + "/brightness" : ""
    readonly property string maxBrightnessPath: _backlightDir !== "" ? _backlightDir + "/max_brightness" : ""

    property string _backlightDir: ""
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

    // Discover backlight device at startup
    Process {
        id: discoverProc
        command: ["ls", "/sys/class/backlight/"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text.trim();
                if (output.length > 0) {
                    const firstDevice = output.split("\n")[0].trim();
                    if (firstDevice.length > 0) {
                        root._backlightDir = "/sys/class/backlight/" + firstDevice;
                        maxBrightnessFile.reload();
                    }
                }
            }
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 || root._backlightDir === "") {
                console.warn("Brightness: No backlight device found in /sys/class/backlight/");
            }
        }
    }

    // Read max brightness once discovered
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
}
