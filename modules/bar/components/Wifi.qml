import QtQuick
import Quickshell
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

TooltipArea {
    id: root
    property bool connected: WifiStatus.connected
    property int signal: WifiStatus.signal // 0-100
    property string ssid: WifiStatus.ssid

    signal clicked

    text: {
        if (!root.connected) {
            return qsTr("Wi‑Fi: disconnected");
        }

        if (root.ssid) {
            return qsTr("%1 — %2%").arg(root.ssid).arg(root.signal);
        }

        return qsTr("Wi‑Fi: connected — %1%").arg(root.signal);
    }

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

    Icon {
        source: Quickshell.iconPath(iconName(), true)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
