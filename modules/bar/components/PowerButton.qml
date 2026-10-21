import QtQuick
import Quickshell

import qs.components
import qs.config
import qs.services

TooltipArea {
    id: root
    implicitWidth: 14
    implicitHeight: 14

    text: "POWER"

    Icon {
        implicitSize: 14
        source: Quickshell.iconPath("system-shutdown-symbolic")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Session.toggle()
    }
}
