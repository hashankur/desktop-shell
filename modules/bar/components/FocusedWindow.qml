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
        source: (Niri.focusedWindow?.appId ?? "") !== "" ? Quickshell.iconPath(Niri.focusedWindow.appId) : ""
        visible: hasIcon && (Niri.focusedWindow?.appId ?? "") !== ""
        layer.enabled: false
    }

    StyledText {
        width: 500
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        text: Niri.focusedWindow?.title ?? "Desktop"
        font.pixelSize: Appearance.fontSize.sm
    }
}
