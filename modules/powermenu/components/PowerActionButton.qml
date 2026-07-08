pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

import qs.components
import qs.config

Item {
    id: root

    property string iconSource: ""
    property string label: ""
    property color iconColor: Appearance.colors.on_surface

    signal clicked

    implicitWidth: 120
    implicitHeight: 100

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: mouseArea.containsMouse ? Appearance.colors.surface_container_high : Appearance.colors.surface_container
        border.color: mouseArea.containsMouse ? Appearance.colors.outline_variant : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.small
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.anim.durations.small
                easing.type: Easing.InOutCubic
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            IconImage {
                implicitSize: 32
                source: root.iconSource
                Layout.alignment: Qt.AlignHCenter
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1.0
                    colorizationColor: root.iconColor
                    brightness: 1.0
                }
            }

            StyledText {
                text: root.label
                font.pixelSize: Appearance.fontSize.sm
                color: root.iconColor
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
