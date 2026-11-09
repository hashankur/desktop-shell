pragma Singleton

import QtQuick
import Quickshell

// Picks the compositor backend once and forwards its state. Only the chosen
// backend is ever referenced, so the other one (and its socket or plugin)
// is never instantiated. Niri sits behind a Loader because its plugin
// import is a hard dependency.
Singleton {
    id: root

    readonly property string kind: {
        if (Quickshell.env("UMBRIEL_SOCKET"))
            return "umbriel";
        if (Quickshell.env("NIRI_SOCKET"))
            return "niri";
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase();
        return desktop.indexOf("umbriel") >= 0 ? "umbriel" : desktop.indexOf("niri") >= 0 ? "niri" : "";
    }

    readonly property var workspaces: root.kind === "umbriel" ? Umbriel.workspaces : root.kind === "niri" ? root._niri?.workspaces ?? null : null
    readonly property string focusedOutputName: root.kind === "umbriel" ? Umbriel.focusedOutputName : root.kind === "niri" ? (root._niri?.focusedOutputName ?? "") : ""
    readonly property string focusedAppId: root.kind === "umbriel" ? Umbriel.focusedAppId : root.kind === "niri" ? (root._niri?.focusedAppId ?? "") : ""
    readonly property string focusedTitle: root.kind === "umbriel" ? Umbriel.focusedTitle : root.kind === "niri" ? (root._niri?.focusedTitle ?? "") : ""
    readonly property bool hasFocusedWindow: root.kind === "umbriel" ? Umbriel.hasFocusedWindow : root.kind === "niri" ? (root._niri?.hasFocusedWindow ?? false) : false

    readonly property var _niri: niriLoader.item

    Loader {
        id: niriLoader
        active: root.kind === "niri"
        source: "niri/NiriBackend.qml"
    }

    // Falls back to the primary screen before the compositor connects.
    readonly property var focusedScreen: {
        const screens = Quickshell.screens;
        const n = screens.length ?? 0;
        for (let i = 0; i < n; i++) {
            if (screens[i].name === root.focusedOutputName)
                return screens[i];
        }
        return n > 0 ? screens[0] : undefined;
    }

    // ws is a workspaces row (the delegate's `model`).
    function focusWorkspace(ws) {
        if (root.kind === "umbriel")
            Umbriel.focusWorkspace(ws.wsIndex, ws.output);
        else if (root.kind === "niri")
            root._niri?.focusWorkspace(ws);
    }
}
