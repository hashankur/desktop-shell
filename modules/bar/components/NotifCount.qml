import QtQuick
import Quickshell

import qs.components
import qs.config
import qs.services

Item {
    id: root

    readonly property bool hovered: hoverHandler.hovered

    readonly property bool allRead: Notifications.unreadCount === 0

    implicitWidth: row.implicitWidth
    implicitHeight: 22

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Dashboard.toggle("overview")
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Appearance.padding.small

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 14
            tint: root.hovered ? Appearance.colors.primary : (root.allRead ? Appearance.colors.on_surface_variant : Appearance.colors.on_surface)
            source: Quickshell.iconPath("preferences-system-notifications-symbolic", true)
        }

        StyledText {
            visible: !root.allRead
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: font.pixelSize / 10
            text: Notifications.unreadCount > 99 ? "99+" : Notifications.unreadCount
            color: root.hovered ? Appearance.colors.primary : Appearance.colors.on_surface
            mono: true
            font.pixelSize: Appearance.fontSize.sm
            font.weight: Font.DemiBold

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }
    }
}
