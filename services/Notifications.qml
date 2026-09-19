pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.modules.notifications

Singleton {
    id: root

    property int maxHistory: 50
    property bool persistenceEnabled: true
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
                id: notification.id
            };

            historyModelStore.insert(0, item);
            while (historyModelStore.count > root.maxHistory) {
                historyModelStore.remove(historyModelStore.count - 1);
            }

            if (root.persistenceEnabled) {
                root.saveHistory();
            }

            root.toastQueued(notification);
        }
    }

    function clearHistory() {
        historyModelStore.clear();
        if (root.persistenceEnabled) {
            root.saveHistory();
        }
    }

    function removeHistory(index) {
        if (index < 0 || index >= historyModelStore.count) {
            return;
        }
        historyModelStore.remove(index);
        if (root.persistenceEnabled) {
            root.saveHistory();
        }
    }

    function saveHistory() {
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

    function findDesktopEntry(notification) {
        const apps = DesktopEntries.applications.values;
        const hint = (notification.desktopEntry || "").toLowerCase();
        if (hint !== "") {
            for (let i = 0; i < apps.length; i++) {
                if (apps[i].id && apps[i].id.toLowerCase() === hint) {
                    return apps[i];
                }
            }
        }
        const appName = (notification.appName || "").toLowerCase().trim();
        if (appName === "") {
            return null;
        }
        for (let i = 0; i < apps.length; i++) {
            const name = (apps[i].name || "").toLowerCase();
            const id = (apps[i].id || "").toLowerCase();
            if (name === appName || id === appName || id.startsWith(appName + "-") || id.startsWith(appName + ".") || name.split(" ")[0] === appName) {
                return apps[i];
            }
        }
        return null;
    }

    function loadHistory() {
        try {
            if (historyFile.loaded) {
                const content = historyFile.text();
                if (content && content.length > 0) {
                    const arr = JSON.parse(content);
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

    Component.onCompleted: {
        if (root.persistenceEnabled) {
            // If file is already loaded, load history immediately
            if (historyFile.loaded) {
                root.loadHistory();
            }
            // Otherwise, the onLoadedChanged signal will trigger the load
        }
    }
}
