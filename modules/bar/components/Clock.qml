import QtQuick

import qs.components
import qs.config
import qs.services

StyledText {
    // Readout voice: mono, tracked, uppercase date.
    mono: true
    text: Time.time.toUpperCase()
    font.letterSpacing: Appearance.tracking.label
    font.pixelSize: Appearance.fontSize.sm
    // Iosevka's caps sit above its line-box center, so centered bar text
    // reads high against the icons; nudge scaled to size (Caelestia pattern).
    anchors.verticalCenterOffset: font.pixelSize / 10

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dashboard.toggle("overview")
    }
}
