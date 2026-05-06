import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
    id: root

    property int maxHistory: 50
    property bool persistenceEnabled: true
    property string persistencePath: "/home/han/.config/quickshell/notifications.json"

    ListModel {
        id: historyModel
    }

    FileView {
        id: historyFile
        path: "/home/han/.config/quickshell/notifications.json"

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
            // Track this notification so it stays in the server
            notification.tracked = true;

            // Add to history
            var item = {
                title: notification.summary || "",
                body: notification.body || "",
                app: notification.appName || "",
                icon: notification.appIcon || "",
                timestamp: Date.now(),
                id: notification.id
            };

            historyModel.insert(0, item);
            while (historyModel.count > root.maxHistory)
                historyModel.remove(historyModel.count - 1);

            if (root.persistenceEnabled) {
                root.saveHistory();
            }

            // Emit event for toast display
            root.notificationEmitted(notification);

            // Auto-dismiss after timeout (let notification handle it)
            var timeoutSec = notification.expireTimeout || 4;
            if (timeoutSec > 0) {
                var expireTimer = Qt.createQmlObject("import QtQuick; Timer { interval: " + (timeoutSec * 1000) + "; running: true; repeat: false }", root);
                // Store reference temporarily
                var notifId = notification.id;
                expireTimer.onTriggered.connect(function () {
                    notification.expire();
                    expireTimer.destroy();
                });
            }
        }
    }

    signal notificationEmitted(var notification)

    function clearHistory() {
        historyModel.clear();
        if (root.persistenceEnabled)
            root.saveHistory();
    }

    function saveHistory() {
        try {
            var arr = [];
            for (var i = 0; i < historyModel.count; i++)
                arr.push(historyModel.get(i));
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
                    for (var i = 0; i < arr.length; i++)
                        historyModel.append(arr[i]);
                }
            }
        } catch (e) {
            console.warn("No persisted notifications or failed to load:", e);
        }
    }

    function openHistory() {
        try {
            var path = "file:///home/han/.config/quickshell/neue/components/NotificationHistory.qml";
            var comp = Qt.createComponent(path);
            if (comp.status === Component.Ready) {
                var w = comp.createObject(null);
                if (!w)
                    console.error("Failed to create NotificationHistory window");
            } else {
                console.warn("NotificationHistory component not ready:", comp.status);
            }
        } catch (e) {
            console.warn("openHistory failed:", e);
        }
    }

    Component.onCompleted: {
        // Load persisted history if enabled
        if (root.persistenceEnabled) {
            // If file is already loaded, load history immediately
            if (historyFile.loaded) {
                root.loadHistory();
            }
            // Otherwise, the onLoadedChanged signal will trigger the load
        }
        // Expose this scope globally so UI can call openHistory / receive events
        try {
            Quickshell.NotificationsUI = root;
            console.info("Notifications module exposed as Quickshell.NotificationsUI");

            // Try to signal NotificationHost that we're ready
            Qt.callLater(function () {
                try {
                    if (typeof root.onReady !== 'undefined') {
                        root.onReady();
                    }
                } catch (e) {}
            });
        } catch (e) {
            console.error("Failed to expose Notifications module:", e);
        }
    }

    signal onReady
}
