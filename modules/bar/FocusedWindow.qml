import QtQuick

import qs.config
import qs.services

Row {
    spacing: 4

    Image {
        anchors.verticalCenter: parent.verticalCenter
        source: Niri.focusedWindow?.iconPath ? "file://" + Niri.focusedWindow?.iconPath : ""
        sourceSize.width: 16
        sourceSize.height: 16
        visible: Niri.focusedWindow?.iconPath !== ""
        smooth: true
    }

    // Fallback for missing icons
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        color: "#CCC"
        visible: Niri.focusedWindow?.iconPath === ""
        radius: 12
    }

    Text {
        // FIXME: Make the width proportional to the width of the container.
        width: 500
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        text: Niri.focusedWindow?.title ?? ""
        font.family: Appearance.font.sans
        font.pixelSize: Appearance.fontSize.normal
        font.weight: Font.Medium
        color: Appearance.colors.on_surface
    }
}
