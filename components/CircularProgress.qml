import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

import qs.config
import qs.components

Item {
    id: circularProgress

    required property real value // 0 to 1
    property string icon: ""  // System icon name
    property color progressColor: Appearance.colors.primary
    property real size: 16
    property real strokeWidth: 2

    // Custom tooltip text; falls back to a percentage when empty
    property string tooltipText: ""

    // Animation properties
    property real animationDuration: Appearance.anim.durations.large

    readonly property real arcRadius: size / 2 - strokeWidth / 2

    implicitWidth: size
    implicitHeight: size

    Behavior on value {
        NumberAnimation {
            duration: circularProgress.animationDuration
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Appearance.colors.secondary_container
            strokeWidth: circularProgress.strokeWidth
            fillColor: "transparent"
            PathAngleArc {
                centerX: circularProgress.width / 2
                centerY: circularProgress.height / 2
                radiusX: circularProgress.arcRadius
                radiusY: circularProgress.arcRadius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: circularProgress.value > 0 ? circularProgress.progressColor : "transparent"
            strokeWidth: circularProgress.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: circularProgress.width / 2
                centerY: circularProgress.height / 2
                radiusX: circularProgress.arcRadius
                radiusY: circularProgress.arcRadius
                startAngle: -90
                sweepAngle: 360 * Math.min(1, Math.max(0, circularProgress.value))
            }
        }
    }

    // Center icon
    Text {
        anchors.centerIn: parent
        text: icon
        font.family: Appearance.font.mono
        font.pixelSize: Math.max(size * 0.4, 12)
        color: progressColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Tooltip
    TooltipArea {
        id: rootTooltip
        anchors.fill: parent
        delay: 300
        text: circularProgress.tooltipText !== "" ? circularProgress.tooltipText : `${Math.round(circularProgress.value * 100)}%`
    }
}
