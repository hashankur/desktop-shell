pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services

RowLayout {
    id: root
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 4

    // Niri output name of the screen this bar lives on; only that
    // output's workspaces are shown.
    property string outputName: ""

    Repeater {
        model: Niri.workspaces

        Rectangle {
            required property var model

            visible: model.output === root.outputName
            Layout.fillWidth: true
            height: parent.height
            color: model.isActive ? Appearance.colors.primary : (model.activeWindowId > 0 ? Appearance.colors.primary_container : Appearance.colors.surface_container)
            opacity: model.isActive ? 1.0 : 0.5

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspaceById(parent.model.id)
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }
    }
}
