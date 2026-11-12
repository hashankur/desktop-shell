import QtQuick
import Quickshell.Widgets
import qs.config

ClippingRectangle {
    id: root

    property real progress: 0.0
    property color barColor: Appearance.colors.primary
    property color backgroundColor: Appearance.colors.surface_container
    property color borderColor: Appearance.colors.surface_container
    property int borderWidth: 0
    property int animationDuration: Appearance.anim.durations.medium

    radius: Appearance.rounding.normal
    color: backgroundColor
    border.color: borderColor
    border.width: borderWidth

    // Progress indicator
    Rectangle {
        id: progressRect
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: root.borderWidth
        }
        width: parent.width * root.progress - (2 * root.borderWidth)
        radius: Math.max(0, parent.radius - root.borderWidth)
        color: root.barColor

        Behavior on width {
            NumberAnimation {
                duration: root.animationDuration
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
        }
    }
}
