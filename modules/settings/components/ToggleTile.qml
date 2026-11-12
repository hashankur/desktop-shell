pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

import qs.components
import qs.config

// Quick-settings toggle: flat icon + label, no card. State reads as the
// primary accent plus an underline (the same tick the band tabs use);
// hover is a color accent only.
Item {
    id: root

    property string iconSource: ""
    property string label: ""
    property bool checked: false

    readonly property color tint: (root.checked || mouseArea.containsMouse) ? Appearance.colors.primary : Appearance.colors.on_surface

    signal clicked

    implicitWidth: 100
    implicitHeight: 76

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
                colorizationColor: root.tint
                brightness: 1.0
            }
        }

        StyledText {
            text: root.label.toUpperCase()
            mono: true
            font.letterSpacing: Appearance.tracking.micro
            font.pixelSize: Appearance.fontSize.sm
            color: root.tint
            Layout.alignment: Qt.AlignHCenter

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: 2
        width: root.checked ? parent.width : 0
        color: Appearance.colors.primary

        Behavior on width {
            NumberAnimation {
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
        onClicked: root.clicked()
    }
}
