import QtQuick
import Quickshell

import qs.components
import qs.config
import qs.services

Row {
    spacing: 5
    readonly property var hasIcon: Quickshell.iconPath(Niri.focusedWindow?.appId, true)

    Icon {
        source: hasIcon ? Quickshell.iconPath(Niri.focusedWindow?.appId + "-symbolic") : ""
        visible: hasIcon
    }

    // Fallback for missing icons
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        color: Appearance.colors.on_surface
        visible: !hasIcon
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
