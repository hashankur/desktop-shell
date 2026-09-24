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

    // Bumped whenever workspace rows change so JS scans over
    // workspaces.get() (which QML can't bind per-row) re-evaluate.
    property int _modelTick: 0

    // Output name (e.g. "eDP-1") of the niri-focused workspace.
    readonly property string focusedOutputName: {
        root._modelTick;
        const ws = root.workspaces;
        if (!ws || ws.count === undefined)
            return "";
        for (let i = 0; i < ws.count; i++) {
            const w = ws.get(i);
            if (!w)
                continue;
            const focused = w.isFocused ?? w.is_focused;
            if (focused)
                return w.output ?? "";
        }
        return "";
    }

    // Quickshell Screen matching the niri-focused output; falls back to
    // the primary screen before niri connects / while undetermined.
    readonly property var focusedScreen: {
        root.focusedOutputName;
        const screens = Quickshell.screens;
        const n = screens.length ?? 0;
        for (let i = 0; i < n; i++) {
            if (screens[i].name === root.focusedOutputName)
                return screens[i];
        }
        return n > 0 ? screens[0] : undefined;
    }

    Connections {
        target: root.workspaces

        function onDataChanged(topLeft, bottomRight, roles) {
            root._modelTick += 1;
        }
        function onModelReset() {
            root._modelTick += 1;
        }
        function onRowsInserted(parent, first, last) {
            root._modelTick += 1;
        }
        function onRowsRemoved(parent, first, last) {
            root._modelTick += 1;
        }
        function onLayoutChanged(topLeft, bottomRight, roles) {
            root._modelTick += 1;
        }
    }

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
