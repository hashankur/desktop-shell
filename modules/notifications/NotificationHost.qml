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
    implicitHeight: 500
    focusable: false
    screen: Quickshell.screens[0]
    anchors.top: true
    anchors.right: true
    margins.top: 18
    margins.right: 18
    margins.bottom: 18
    margins.left: 18
    exclusiveZone: 0

    property var activeToasts: []
    property int toastCount: 0
    visible: toastCount > 0

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
        var toastData = {
            title: notification.summary || "",
            body: notification.body || "",
            icon: notification.appIcon || "",
            timestamp: Date.now(),
            timeout: notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : 4000
        }

        var obj = toastComponent.createObject(stack, { notificationData: toastData, notificationObject: notification })
        if (obj) {
            activeToasts.push(obj)
            toastCount = activeToasts.length

            // Keep host visibility in sync after toast self-destruction.
            obj.destroyed.connect(function() {
                for (var i = activeToasts.length - 1; i >= 0; --i) {
                    if (activeToasts[i] === obj || activeToasts[i] === null) {
                        activeToasts.splice(i, 1)
                    }
                }
                toastCount = activeToasts.length
            })
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
