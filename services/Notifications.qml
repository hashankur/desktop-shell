pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property int maxHistory: 50
    property bool persistenceEnabled: true
    // Do not disturb: suppresses toasts only — history still records.
    property bool dnd: false
    readonly property string persistencePath: Quickshell.env("HOME") + "/.config/quickshell/notifications.json"

    signal toastQueued(var notification)

    ListModel {
        id: historyModelStore
    }

    property alias historyModel: historyModelStore

    FileView {
        id: historyFile
        path: root.persistencePath

        onSaveFailed: function (error) {
            console.error("Failed to save notifications:", error);
        }

        onLoadedChanged: {
            if (loaded && root.persistenceEnabled) {
                root.loadHistory();
            }
        }
    }

    NotificationServer {
        id: notificationServer
        bodySupported: true
        imageSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        keepOnReload: true

        onNotification: function (notification) {
            notification.tracked = true;

            const item = {
                title: notification.summary || "",
                body: notification.body || "",
                app: notification.appName || "",
                icon: root.resolveAppIcon(notification),
                image: root.persistableImage(notification.image || ""),
                timestamp: Date.now(),
                urgency: notification.urgency,
                id: notification.id
            };

            historyModelStore.insert(0, item);
            while (historyModelStore.count > root.maxHistory) {
                historyModelStore.remove(historyModelStore.count - 1);
            }

            if (root.persistenceEnabled) {
                root.saveHistory();
            }

            // Critical notifications cut through do-not-disturb.
            if (!root.dnd || notification.urgency === NotificationUrgency.Critical) {
                root.toastQueued(notification);
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: root.writeHistory()
    }

    function clearHistory() {
        historyModelStore.clear();
        if (root.persistenceEnabled) {
            root.writeHistory();
        }
    }

    function removeHistory(index) {
        if (index < 0 || index >= historyModelStore.count) {
            return;
        }
        historyModelStore.remove(index);
        if (root.persistenceEnabled) {
            root.writeHistory();
        }
    }

    function saveHistory() {
        saveTimer.restart();
    }

    function writeHistory() {
        try {
            const arr = [];
            for (let i = 0; i < historyModelStore.count; i++) {
                arr.push(historyModelStore.get(i));
            }
            historyFile.setText(JSON.stringify(arr));
        } catch (e) {
            console.error("Failed to save notifications to history:", e);
        }
    }

    function persistableImage(image) {
        if (image.startsWith("image://qsimage/") || image.startsWith("image://qspixmap/")) {
            return "";
        }
        return image;
    }

    function resolveAppIcon(notification) {
        try {
            if (notification.appIcon && notification.appIcon !== "") {
                return notification.appIcon;
            }
            const entry = root.findDesktopEntry(notification);
            if (entry && entry.icon) {
                return entry.icon;
            }
        } catch (e) {
            console.warn("Failed to resolve notification icon:", e);
        }
        return "";
    }

    property var _desktopEntryCache: ({})

    function findDesktopEntry(notification) {
        const hint = (notification.desktopEntry || "").toLowerCase();
        const appName = (notification.appName || "").toLowerCase().trim();
        const key = hint + "\n" + appName;
        if (key in root._desktopEntryCache) {
            return root._desktopEntryCache[key];
        }
        const apps = DesktopEntries.applications.values || [];
        let found = null;
        if (apps.length > 0) {
            if (hint !== "") {
                for (let i = 0; i < apps.length; i++) {
                    if (apps[i].id && apps[i].id.toLowerCase() === hint) {
                        found = apps[i];
                        break;
                    }
                }
            }
            if (found === null && appName !== "") {
                for (let i = 0; i < apps.length; i++) {
                    const name = (apps[i].name || "").toLowerCase();
                    const id = (apps[i].id || "").toLowerCase();
                    if (name === appName || id === appName || id.startsWith(appName + "-") || id.startsWith(appName + ".") || name.split(" ")[0] === appName) {
                        found = apps[i];
                        break;
                    }
                }
            }
            root._desktopEntryCache[key] = found;
        }
        return found;
    }

    function loadHistory() {
        if (_historyLoaded) {
            return;
        }
        try {
            if (historyFile.loaded) {
                _historyLoaded = true;
                const content = historyFile.text();
                if (content && content.length > 0) {
                    const arr = JSON.parse(content);
                    historyModelStore.clear();
                    for (let i = 0; i < arr.length; i++) {
                        arr[i].image = root.persistableImage(arr[i].image || "");
                        if (!arr[i].icon) {
                            arr[i].icon = root.resolveAppIcon({
                                appIcon: "",
                                desktopEntry: "",
                                appName: arr[i].app || ""
                            });
                        }
                        historyModelStore.append(arr[i]);
                    }
                }
            }
        } catch (e) {
            console.warn("No persisted notifications or failed to load:", e);
        }
    }

    property bool _historyLoaded: false

    Component.onCompleted: {
        if (root.persistenceEnabled) {
            // If file is already loaded, load history immediately;
            // otherwise the onLoadedChanged signal will trigger the load.
            root.loadHistory();
        }
    }
}
