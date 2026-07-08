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
    property string persistencePath: "/home/han/.config/quickshell/notifications.json"
    property var pendingToasts: []

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
                icon: notification.appIcon || "",
                image: notification.image || "",
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

            root.pendingToasts.push(notification);
            root.toastQueued(notification);
        }
    }

    function clearHistory() {
        historyModelStore.clear();
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

    function loadHistory() {
        try {
            if (historyFile.loaded) {
                const content = historyFile.text();
                if (content && content.length > 0) {
                    const arr = JSON.parse(content);
                    for (let i = 0; i < arr.length; i++) {
                        historyModelStore.append(arr[i]);
                    }
                }
            }
        } catch (e) {
            console.warn("No persisted notifications or failed to load:", e);
        }
    }

    function takePendingToasts() {
        const queued = root.pendingToasts.slice();
        root.pendingToasts = [];
        return queued;
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
