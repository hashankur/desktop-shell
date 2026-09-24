pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int maxRecents: 10
    readonly property string persistencePath: Quickshell.env("HOME") + "/.config/quickshell/launcher-state.json"

    // Desktop-entry ids only; entries are resolved against DesktopEntries at read time.
    property var pinnedIds: []
    property var recentIds: []
    property bool _stateLoaded: false

    FileView {
        id: stateFile
        path: root.persistencePath

        onSaveFailed: function (error) {
            console.error("Failed to save launcher state:", error);
        }

        onLoadedChanged: {
            if (loaded) {
                root.loadState();
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: root.writeState()
    }

    Component.onCompleted: {
        // If the file is already loaded, load immediately; otherwise
        // onLoadedChanged will trigger the load.
        root.loadState();
    }

    function loadState() {
        if (root._stateLoaded) {
            return;
        }
        try {
            if (stateFile.loaded) {
                root._stateLoaded = true;
                const content = stateFile.text();
                if (content && content.length > 0) {
                    const data = JSON.parse(content);
                    if (Array.isArray(data.pinned)) {
                        root.pinnedIds = data.pinned.filter(function (id) {
                            return typeof id === "string" && id.length > 0;
                        });
                    }
                    if (Array.isArray(data.recents)) {
                        root.recentIds = data.recents.filter(function (id) {
                            return typeof id === "string" && id.length > 0;
                        });
                    }
                }
            }
        } catch (e) {
            console.warn("No persisted launcher state or failed to load:", e);
        }
    }

    function writeState() {
        try {
            stateFile.setText(JSON.stringify({
                pinned: root.pinnedIds,
                recents: root.recentIds
            }));
        } catch (e) {
            console.error("Failed to save launcher state:", e);
        }
    }

    function saveState() {
        saveTimer.restart();
    }

    function isPinned(id) {
        return root.pinnedIds.indexOf(id) !== -1;
    }

    function togglePin(id) {
        if (!id) {
            return;
        }
        if (root.isPinned(id)) {
            root.pinnedIds = root.pinnedIds.filter(function (p) {
                return p !== id;
            });
        } else {
            root.pinnedIds = root.pinnedIds.concat([id]);
        }
        root.saveState();
    }

    function recordLaunch(id) {
        if (!id) {
            return;
        }
        root.recentIds = [id].concat(root.recentIds.filter(function (r) {
            return r !== id;
        })).slice(0, root.maxRecents);
        root.saveState();
    }

    function _entryById(id) {
        const apps = DesktopEntries.applications.values || [];
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].id === id) {
                return apps[i];
            }
        }
        return null;
    }

    // Pinned desktop entries in pin order; ids that no longer resolve are skipped.
    function pinnedEntries() {
        const out = [];
        for (let i = 0; i < root.pinnedIds.length; i++) {
            const app = root._entryById(root.pinnedIds[i]);
            if (app) {
                out.push(app);
            }
        }
        return out;
    }

    // Recent desktop entries, newest first, excluding pinned apps.
    function recentEntries() {
        const out = [];
        for (let i = 0; i < root.recentIds.length; i++) {
            const id = root.recentIds[i];
            if (root.isPinned(id)) {
                continue;
            }
            const app = root._entryById(id);
            if (app) {
                out.push(app);
            }
        }
        return out;
    }
}
