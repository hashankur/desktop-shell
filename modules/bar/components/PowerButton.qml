import QtQuick
import Quickshell

import qs.components
import qs.config
import qs.services

TooltipArea {
    id: root
    implicitWidth: 16
    implicitHeight: 16

    text: "Power"

    Icon {
        source: Quickshell.iconPath("system-shutdown-symbolic")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Session.toggle()
    }
}
