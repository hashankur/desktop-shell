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
    property int animationDuration: 300

    radius: height / 2
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
        radius: Math.min(parent.radius - root.borderWidth, width / 2)
        color: root.barColor

        Behavior on width {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.InOutQuad
            }
        }
    }
}
