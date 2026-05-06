import Quickshell
import QtQuick

import qs.components
import qs.services

Rectangle {
    width: 20
    height: 20
    radius: 6
    color: "transparent"

    Icon {
        source: Quickshell.iconPath("preferences-system-notifications-symbolic")
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            try {
                Dashboard.open("overview");
            } catch (e) {
                console.warn("Failed opening notifications:", e);
            }
        }
    }
}
