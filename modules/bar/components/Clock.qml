import QtQuick

import qs.config
import qs.services

Text {
    text: Time.time
    color: Appearance.colors.on_surface
    font.family: Appearance.font.sans
    font.pixelSize: Appearance.fontSize.normal
    font.weight: Font.Medium
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dashboard.toggle("overview")
    }
}
