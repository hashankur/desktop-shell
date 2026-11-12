pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Umbriel backend for Compositor. Rows keep the qml-niri shape (isActive,
// isFocused, activeWindowId, id, output) so consumers do not care which
// compositor feeds them; wsIndex/name are extra, for switching.
Singleton {
    id: root

    // Singletons are created eagerly, so each backend gates itself on the
    // variable only its own compositor sets.
    readonly property string socketPath: Quickshell.env("UMBRIEL_SOCKET") || ""

    readonly property alias workspaces: wsModel
    property string focusedOutputName: ""
    property string focusedAppId: ""
    property string focusedTitle: ""
    property bool hasFocusedWindow: false

    property int _retryDelay: 1000
    property string _wsSig: ""

    ListModel {
        id: wsModel
    }

    function focusWorkspace(wsIndex, output) {
        root._send({
            cmd: "msg",
            arg: "workspace-switch:" + wsIndex + (output ? "/" + output : "")
        });
    }

    // Build 2026-10-04 takes {"cmd":"msg","arg":"<action>"}; the docs'
    // typed {"cmd":"action",...} form is rejected as "unknown command".
    function _send(request) {
        if (!actionSocket.connected) {
            root._pending = JSON.stringify(request) + "\n";
            actionSocket.connected = true;
            return;
        }
        actionSocket.write(JSON.stringify(request) + "\n");
        actionSocket.flush();
    }

    property string _pending: ""

    function _onLine(line) {
        if (line === "")
            return;
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            console.warn("Umbriel: bad line", line.slice(0, 80));
            return;
        }
        if (msg.err !== undefined) {
            console.warn("Umbriel:", msg.err);
            return;
        }
        if (msg.event === "workspaces")
            root._applyWorkspaces(msg.data || []);
        else if (msg.event === "windows")
            root._applyWindows(msg.data || []);
    }

    function _applyWorkspaces(list) {
        // Window events carry titles and geometry; the bar only needs this
        // subset, so an unchanged signature leaves the model alone.
        const rows = list.map(w => ({
                    id: w.id,
                    wsIndex: w.index,
                    name: w.name || "",
                    output: w.output,
                    isActive: w.active,
                    isFocused: w.focused,
                    activeWindowId: w.occupied ? 1 : 0
                }));
        const sig = JSON.stringify(rows);
        if (sig === root._wsSig)
            return;
        root._wsSig = sig;

        let focusedOutput = "";
        for (const r of rows) {
            if (r.isFocused)
                focusedOutput = r.output;
        }
        root.focusedOutputName = focusedOutput;

        let sameShape = wsModel.count === rows.length;
        for (let i = 0; sameShape && i < rows.length; i++)
            sameShape = wsModel.get(i).id === rows[i].id;

        if (!sameShape) {
            wsModel.clear();
            for (const r of rows)
                wsModel.append(r);
            return;
        }
        for (let i = 0; i < rows.length; i++) {
            for (const key of Object.keys(rows[i])) {
                if (wsModel.get(i)[key] !== rows[i][key])
                    wsModel.setProperty(i, key, rows[i][key]);
            }
        }
    }

    function _applyWindows(list) {
        let focused = null;
        for (const w of list) {
            if (w.active) {
                focused = w;
                break;
            }
        }
        root.hasFocusedWindow = focused !== null;
        root.focusedAppId = focused ? (focused.app_id || "") : "";
        root.focusedTitle = focused ? (focused.title || "") : "";
    }

    Socket {
        id: eventSocket
        path: root.socketPath
        parser: SplitParser {
            onRead: data => root._onLine(data)
        }
        onConnectedChanged: {
            if (connected) {
                root._retryDelay = 1000;
                console.info("Connected to umbriel");
                write(JSON.stringify({
                    cmd: "subscribe",
                    events: ["workspaces", "windows"]
                }) + "\n");
                flush();
            } else {
                root._wsSig = "";
                retryTimer.restart();
            }
        }
        onError: error => console.warn("Umbriel socket error:", error)
    }

    Socket {
        id: actionSocket
        path: root.socketPath
        parser: SplitParser {
            onRead: data => {
                try {
                    const msg = JSON.parse(data);
                    if (msg.err !== undefined)
                        console.warn("Umbriel action:", msg.err);
                } catch (e) {}
                actionSocket.connected = false;
            }
        }
        onConnectedChanged: {
            if (connected && root._pending !== "") {
                write(root._pending);
                flush();
                root._pending = "";
            }
        }
    }

    Component.onCompleted: {
        if (root.socketPath !== "")
            eventSocket.connected = true;
    }

    // Same backoff as Niri: if the compositor restarts or the socket is not
    // up yet, the bar would otherwise stay dead until a reload.
    Timer {
        id: retryTimer
        interval: root._retryDelay
        onTriggered: {
            root._retryDelay = Math.min(root._retryDelay * 2, 30000);
            eventSocket.connected = true;
        }
    }
}
