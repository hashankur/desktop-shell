import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import qs.services
import "components"

PanelWindow {
    id: host
    color: "transparent"
    implicitWidth: 400
    implicitHeight: stack.implicitHeight
    focusable: false
    screen: Quickshell.screens[0]
    anchors.top: true
    anchors.right: true
    margins.top: 18
    margins.right: 18
    margins.bottom: 18
    margins.left: 18
    exclusiveZone: 0

    visible: _toasts.length > 0

    property var _toasts: []

    Component {
        id: toastComponent
        NotificationToast {}
    }

    Column {
        id: stack
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 12
        width: 400
    }

    function pushToast(notification) {
        const obj = toastComponent.createObject(stack, {
            notificationData: {
                title: notification.summary || "",
                body: notification.body || "",
                icon: Notifications.resolveAppIcon(notification),
                image: notification.image || "",
                app: notification.appName || "",
                timestamp: Date.now(),
                timeout: notification.expireTimeout > 0 ? notification.expireTimeout : 4000
            },
            notificationObject: notification
        });

        if (obj) {
            _toasts = _toasts.concat(obj);
            obj.dismissed.connect(() => removeToast(obj));
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
