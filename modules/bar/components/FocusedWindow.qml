import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

Row {
    spacing: 10
    readonly property var hasIcon: Quickshell.iconPath(Niri.focusedWindow?.appId, true)

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        source: hasIcon ? Quickshell.iconPath(Niri.focusedWindow?.appId + "-symbolic") : Quickshell.iconPath(Niri.focusedWindow?.appId)
        visible: hasIcon
    }

    // // Fallback for missing icons
    // Rectangle {
    //     anchors.verticalCenter: parent.verticalCenter
    //     width: 14
    //     height: 14
    //     color: Appearance.colors.on_surface
    //     visible: !hasIcon
    //     radius: 12
    // }

    StyledText {
        width: 500
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        text: Niri.focusedWindow?.title ?? "Desktop"
        font.pixelSize: Appearance.fontSize.sm
    }
}
