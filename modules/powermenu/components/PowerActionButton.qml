pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

import qs.components
import qs.config

// Session action cell: flat icon + label under an index tag. Cells are
// divided by Rules in the pane, not boxed; hover is a color accent.
Item {
    id: root

    property string iconSource: ""
    property string label: ""
    property color iconColor: Appearance.colors.on_surface
    property string indexLabel: ""

    readonly property color tint: mouseArea.containsMouse ? Appearance.colors.primary : root.iconColor

    signal clicked

    implicitWidth: 120
    implicitHeight: 110

    HudLabel {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal
        visible: root.indexLabel.length > 0
        label: root.indexLabel
        accent: true
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

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
