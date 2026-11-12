pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keep-awake switch. The Wayland inhibitor itself has to hang off a mapped
// surface, so each bar window carries an `IdleInhibitor` bound to `enabled`
// (see Bar.qml); this singleton only owns the state. Session-only on purpose:
// a forgotten inhibitor should not survive a restart.
Singleton {
    id: root

    property bool enabled: false

    function toggle() {
        root.enabled = !root.enabled;
    }

    IpcHandler {
        target: "idleinhibit"

        function toggle(): void {
            root.toggle();
        }
        function enable(): void {
            root.enabled = true;
        }
        function disable(): void {
            root.enabled = false;
        }
        function isEnabled(): bool {
            return root.enabled;
        }
    }
}
