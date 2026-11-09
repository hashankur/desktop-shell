import QtQuick
import Quickshell

import qs.components
import qs.config
import qs.services

TooltipArea {
    id: root

    visible: WiredStatus.connected
    text: WiredStatus.label

    implicitWidth: visible ? 14 : 0
    implicitHeight: 14

    // The theme has no USB-ethernet glyph, so a USB adapter reads as wired
    // and the tooltip says which it is.
    Icon {
        implicitSize: 14
        source: Quickshell.iconPath(WiredStatus.kind === "phone" ? "phone-symbolic" : "network-wired-symbolic", true)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Settings.toggle("network")
    }
}
