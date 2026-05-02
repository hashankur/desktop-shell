import QtQuick
import Quickshell
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

Row {
    spacing: 5
    readonly property var hasIcon: Quickshell.iconPath(Niri.focusedWindow?.appId, true)

    // IconImage {
    //     implicitSize: 14
    //     anchors.verticalCenter: parent.verticalCenter
    //     smooth: true
    //     source: hasIcon ? Quickshell.iconPath(Niri.focusedWindow?.appId) : ""
    //     visible: hasIcon
    // }

    // // Fallback for missing icons
    // Rectangle {
    //     anchors.verticalCenter: parent.verticalCenter
    //     width: 14
    //     height: 14
    //     color: Appearance.colors.on_surface
    //     visible: !hasIcon
    //     radius: 12
    // }

    Text {
        width: 500
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        text: Niri.focusedWindow?.title ?? "Desktop"
        font.family: Appearance.font.sans
        font.pixelSize: Appearance.fontSize.normal
        font.weight: Font.Medium
        color: Appearance.colors.on_surface
    }
}
