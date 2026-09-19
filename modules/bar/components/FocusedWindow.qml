import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

Row {
    id: root
    spacing: 10
    readonly property string appId: Niri.focusedWindow?.appId ?? ""
    readonly property string iconName: root.desktopIconName(root.appId)
    readonly property string symbolicSource: root.iconName !== "" ? Quickshell.iconPath(root.iconName + "-symbolic", true) : ""
    readonly property string fullSource: root.iconName !== "" && root.symbolicSource === "" ? Quickshell.iconPath(root.iconName, true) : ""

    function desktopIconName(appId) {
        if (appId === "") {
            return "user-desktop";
        }
        const apps = DesktopEntries.applications.values || [];
        const lowerId = appId.toLowerCase();
        for (let i = 0; i < apps.length; i++) {
            const entryId = (apps[i].id || "").toLowerCase();
            if ((entryId === lowerId || entryId === lowerId + ".desktop") && apps[i].icon) {
                return apps[i].icon;
            }
        }
        return appId;
    }

    Icon {
        source: root.symbolicSource
        visible: root.symbolicSource !== ""
    }

    IconImage {
        implicitSize: 16
        anchors.verticalCenter: parent.verticalCenter
        source: root.fullSource
        visible: root.fullSource !== ""
        smooth: true
    }

    StyledText {
        width: 500
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        text: Niri.focusedWindow?.title ?? "Desktop"
        font.pixelSize: Appearance.fontSize.sm
    }
}
