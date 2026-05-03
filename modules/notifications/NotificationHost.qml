import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import qs.services

PanelWindow {
    id: host
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 500
    screen: Quickshell.screens[0]
    anchors.top: true
    anchors.right: true
    margins.top: 18
    margins.right: 18
    margins.bottom: 18
    margins.left: 18
    exclusiveZone: 0

    property var activeToasts: []

    Column {
        id: stack
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 12
        width: 400
    }

    function pushToast(notification) {
        var toastData = {
            title: notification.summary || "",
            body: notification.body || "",
            icon: notification.appIcon || "",
            timestamp: Date.now(),
            timeout: notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : 4000
        }

        var comp = Qt.createComponent(Qt.resolvedUrl("./components/NotificationToast.qml"))
        if (comp.status === Component.Ready) {
            var obj = comp.createObject(stack, { notificationData: toastData, notificationObject: notification })
            if (obj) {
                activeToasts.push(obj)
            }
        } else {
            console.warn("Toast component not ready:", comp.status, comp.errorString())
        }
    }

    Component.onCompleted: {
        var pending = Notifications.takePendingToasts()
        for (var i = 0; i < pending.length; i++) {
            pushToast(pending[i])
        }
    }

    Connections {
        target: Notifications

        function onToastQueued(notification) {
            pushToast(notification)
        }
    }
}
