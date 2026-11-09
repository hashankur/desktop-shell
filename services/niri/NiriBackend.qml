import QtQuick
import Quickshell
import Niri 0.1

// Loaded by Compositor only on niri: the plugin import below is a hard
// dependency, so keeping it in its own file lets the shell start without it.
Item {
    id: root
    visible: false

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

    readonly property bool hasFocusedWindow: root.focusedWindow !== null && root.focusedWindow !== undefined
    readonly property string focusedAppId: root.focusedWindow?.appId ?? ""
    readonly property string focusedTitle: root.focusedWindow?.title ?? ""

    // Workspace updates arrive in bursts; one tick per event-loop turn keeps
    // the focused-output scan from running once per row signal.
    property bool _bumpQueued: false
    function _bump() {
        if (root._bumpQueued)
            return;
        root._bumpQueued = true;
        Qt.callLater(() => {
            root._bumpQueued = false;
            root._modelTick += 1;
        });
    }

    Connections {
        target: root.workspaces

        function onDataChanged(topLeft, bottomRight, roles) {
            root._bump();
        }
        function onModelReset() {
            root._bump();
        }
        function onRowsInserted(parent, first, last) {
            root._bump();
        }
        function onRowsRemoved(parent, first, last) {
            root._bump();
        }
        function onLayoutChanged(topLeft, bottomRight, roles) {
            root._bump();
        }
    }

    function focusWorkspace(ws) {
        niri.focusWorkspaceById(ws.id);
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

    Component.onCompleted: {
        if (Quickshell.env("NIRI_SOCKET"))
            niri.connect();
    }

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
