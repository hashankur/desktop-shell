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
    property var historyWindow: null

    Component {
        id: historyWindowComponent

        NotificationHistory {}
    }

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
        actionsSupported: true
        actionIconsSupported: true
        keepOnReload: true

        onNotification: function (notification) {
            notification.tracked = true;

            var item = {
                title: notification.summary || "",
                body: notification.body || "",
                app: notification.appName || "",
                icon: notification.appIcon || "",
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
            var arr = [];
            for (var i = 0; i < historyModelStore.count; i++) {
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
                var content = historyFile.text();
                if (content && content.length > 0) {
                    var arr = JSON.parse(content);
                    for (var i = 0; i < arr.length; i++) {
                        historyModelStore.append(arr[i]);
                    }
                }
            }
        } catch (e) {
            console.warn("No persisted notifications or failed to load:", e);
        }
    }

    function takePendingToasts() {
        var queued = root.pendingToasts.slice();
        root.pendingToasts = [];
        return queued;
    }

    function openHistory() {
        try {
            if (root.historyWindow) {
                root.historyWindow.visible = true;
                return;
            }

            root.historyWindow = historyWindowComponent.createObject(null);
            if (!root.historyWindow) {
                console.error("Failed to create NotificationHistory window");
                return;
            }

            root.historyWindow.visible = true;
        } catch (e) {
            console.warn("openHistory failed:", e);
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
