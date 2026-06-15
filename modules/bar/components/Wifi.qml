import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

Item {
    id: root
    property bool connected: WifiStatus.connected
    property int signal: WifiStatus.signal // 0-100
    property string ssid: WifiStatus.ssid

    signal clicked

    implicitWidth: 16
    implicitHeight: 16

    function iconName() {
        if (!root.connected)
            return "network-wireless-offline-symbolic";
        if (root.signal > 90)
            return "network-wireless-signal-excellent-symbolic";
        if (root.signal > 70)
            return "network-wireless-signal-good-symbolic";
        if (root.signal > 40)
            return "network-wireless-signal-ok-symbolic";
        if (root.signal > 0)
            return "network-wireless-signal-weak-symbolic";
        return "network-wireless-signal-none-symbolic";
    }

    // Icon image
    Icon {
        id: img
        source: Quickshell.iconPath(iconName(), true)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    ToolTip {
        visible: ma.containsMouse
        text: {
            if (!root.connected) {
                return qsTr("Wi‑Fi: disconnected");
            }

            if (root.ssid) {
                return qsTr("%1 — %2%").arg(root.ssid).arg(root.signal);
            }

            return qsTr("Wi‑Fi: connected — %1%").arg(root.signal);
        }
    }
}
