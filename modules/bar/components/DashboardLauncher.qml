import Quickshell
import QtQuick

import qs.components
import qs.services

Item {
    width: 20
    height: 20

    Icon {
        source: Quickshell.iconPath("view-grid-symbolic")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dashboard.toggle("overview")
    }
}
