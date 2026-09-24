pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

import qs.components
import qs.config

// Quick-settings toggle tile: PowerActionButton-style with a checked state.
Item {
    id: root

    property string iconSource: ""
    property string label: ""
    property bool checked: false

    signal clicked

    implicitWidth: 100
    implicitHeight: 80

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: (mouseArea.containsMouse || root.checked) ? Appearance.colors.surface_container_high : Appearance.colors.surface_container
        border.color: root.checked ? Appearance.colors.primary : (mouseArea.containsMouse ? Appearance.colors.outline_variant : "transparent")
        border.width: 1

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
                implicitSize: 26
                source: root.iconSource
                Layout.alignment: Qt.AlignHCenter
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1.0
                    colorizationColor: root.checked ? Appearance.colors.primary : Appearance.colors.on_surface
                    brightness: 1.0
                }
            }

            StyledText {
                text: root.label
                font.pixelSize: Appearance.fontSize.sm
                color: root.checked ? Appearance.colors.primary : Appearance.colors.on_surface
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
