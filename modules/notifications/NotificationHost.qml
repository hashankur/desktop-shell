import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications

import qs.services
import "components"

PanelWindow {
    id: host
    color: "transparent"
    implicitWidth: 400
    implicitHeight: stack.implicitHeight
    focusable: false
    screen: Niri.focusedScreen
    anchors.top: true
    anchors.right: true
    margins.top: 18
    margins.right: 18
    margins.bottom: 18
    margins.left: 18
    exclusiveZone: 0

    visible: _toasts.length > 0

    property var _toasts: []
    readonly property int maxToasts: 5

    Component {
        id: toastComponent
        // Live toasts slide in from the right edge of the stack.
        NotificationToast {
            slideIn: true
        }
    }

    Column {
        id: stack
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 12
        width: 400
    }

    function pushToast(notification) {
        const critical = notification.urgency === NotificationUrgency.Critical;
        const obj = toastComponent.createObject(stack, {
            notificationData: {
                title: notification.summary || "",
                body: notification.body || "",
                icon: Notifications.resolveAppIcon(notification),
                image: notification.image || "",
                app: notification.appName || "",
                timestamp: Date.now(),
                urgency: notification.urgency,
                timeout: notification.expireTimeout > 0 ? notification.expireTimeout : 4000
            },
            notificationObject: notification,
            // Critical toasts stay until dismissed.
            autoHideEnabled: !critical
        });

        if (!obj) {
            // Creation failed — release the notification so it isn't
            // retained forever with tracked = true.
            console.warn("Failed to create notification toast");
            notification.dismiss();
            return;
        }

        _toasts = _toasts.concat(obj);
        obj.dismissed.connect(() => removeToast(obj));

        while (_toasts.length > maxToasts) {
            removeToast(_toasts[0]);
        }
    }

    function removeToast(obj) {
        _toasts = _toasts.filter(toast => toast !== obj);
        obj.destroy();
    }

    Connections {
        target: Notifications
        function onToastQueued(notification) {
            pushToast(notification);
        }
    }
}
