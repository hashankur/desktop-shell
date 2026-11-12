import QtQuick
import Quickshell

import qs.components
import qs.config
import qs.services

// Shown only while the idle inhibitor is on, so it cannot be forgotten.
// Clicking it is the way back to normal idling.
TooltipArea {
    id: root

    visible: IdleInhibit.enabled
    text: "AWAKE · click to allow idle"

    implicitWidth: visible ? 14 : 0
    implicitHeight: 14

    Icon {
        implicitSize: 14
        source: Quickshell.iconPath("view-reveal-symbolic", true)
        tint: mouseArea.containsMouse ? Appearance.colors.primary : Appearance.colors.on_surface

        Behavior on tint {
            ColorAnimation {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: IdleInhibit.enabled = false
    }
}
