import QtQuick

import qs.components
import qs.config
import qs.services

StyledText {
    text: Time.time
    font.pixelSize: Appearance.fontSize.sm

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dashboard.toggle("overview")
    }
}
