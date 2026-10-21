import QtQuick

import qs.components
import qs.config
import qs.services

StyledText {
    // Readout voice: mono, tracked, uppercase date.
    mono: true
    text: Time.time.toUpperCase()
    font.letterSpacing: Appearance.tracking.label
    font.pixelSize: Appearance.fontSize.xs

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dashboard.toggle("overview")
    }
}
