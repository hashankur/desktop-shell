import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services

RowLayout {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 4

    Repeater {
        model: Niri.workspaces

        Rectangle {
            Layout.fillWidth: true
            height: parent.height
            color: model.isActive ? Appearance.colors.primary : (model.activeWindowId > 0 ? Appearance.colors.primary_container : Appearance.colors.surface_container)
            opacity: model.isActive ? 1.0 : 0.5
            // scale: model.isActive ? 1.05 : 1.0

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspaceById(model.id)
            }

            Behavior on scale {
                PropertyAnimation {
                    duration: 150
                    easing.type: Easing.InOutQuad
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }
}
