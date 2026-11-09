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
    readonly property string appId: Compositor.focusedAppId
    readonly property string iconName: root.desktopIconName(root.appId)
    readonly property string symbolicSource: root.iconName !== "" ? Quickshell.iconPath(root.iconName + "-symbolic", true) : ""
    readonly property string fullSource: root.iconName !== "" && root.symbolicSource === "" ? Quickshell.iconPath(root.iconName, true) : ""

    // Focus changes fire often; the desktop-entry scan is O(n) so memoize.
    property var _iconCache: ({})

    function desktopIconName(appId) {
        if (appId === "") {
            return "user-desktop";
        }
        if (appId in root._iconCache) {
            return root._iconCache[appId];
        }
        const apps = DesktopEntries.applications.values || [];
        const lowerId = appId.toLowerCase();
        let result = appId;
        for (let i = 0; i < apps.length; i++) {
            const entryId = (apps[i].id || "").toLowerCase();
            if ((entryId === lowerId || entryId === lowerId + ".desktop") && apps[i].icon) {
                result = apps[i].icon;
                break;
            }
        }
        root._iconCache[appId] = result;
        return result;
    }

    Icon {
        implicitSize: 14
        source: root.symbolicSource
        visible: root.symbolicSource !== ""
    }

    IconImage {
        implicitSize: 14
        anchors.verticalCenter: parent.verticalCenter
        source: root.fullSource
        visible: root.fullSource !== ""
        smooth: true
    }

    StyledText {
        width: 500
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: font.pixelSize / 10
        text: Compositor.hasFocusedWindow ? Compositor.focusedTitle : "Desktop"
        mono: true
        font.pixelSize: Appearance.fontSize.sm
    }
}
