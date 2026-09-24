pragma Singleton

import QtQuick
import Quickshell
import Niri 0.1

Singleton {
    id: root

    // Forwarded from the plugin object so consumers see a stable API.
    readonly property var workspaces: niri.workspaces
    readonly property var focusedWindow: niri.focusedWindow

    property int _retryDelay: 1000

    function focusWorkspaceById(id) {
        niri.focusWorkspaceById(id);
    }

    Niri {
        id: niri

        onConnected: {
            console.info("Connected to niri");
            root._retryDelay = 1000;
        }
        onErrorOccurred: function (error) {
            console.error("Niri error:", error);
            retryTimer.restart();
        }
    }

    Component.onCompleted: niri.connect()

    // Reconnect with exponential backoff: if the socket isn't up when the
    // shell starts, workspaces/focused-window would otherwise stay dead
    // until a reload.
    Timer {
        id: retryTimer
        interval: root._retryDelay
        onTriggered: {
            root._retryDelay = Math.min(root._retryDelay * 2, 30000);
            niri.connect();
        }
    }
}
