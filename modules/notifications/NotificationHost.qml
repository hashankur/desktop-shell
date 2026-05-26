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

    visible: stack.children.length > 0

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
        var obj = toastComponent.createObject(stack, {
            notificationData: {
                title: notification.summary || "",
                body: notification.body || "",
                icon: notification.appIcon || "",
                image: notification.image || "",
                app: notification.appName || "",
                timestamp: Date.now(),
                timeout: notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : 4000
            },
            notificationObject: notification
        });

        if (obj) {
            obj.dismissed.connect(() => obj.destroy());
        }
    }

    Component.onCompleted: {
        var pending = Notifications.takePendingToasts();
        for (var i = 0; i < pending.length; i++) {
            pushToast(pending[i]);
        }
    }

    Connections {
        target: Notifications
        function onToastQueued(notification) {
            pushToast(notification);
        }
    }
}
