import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config
import qs.components

Item {
    id: circularProgress

    required property real value // 0 to 1
    property string icon: ""  // System icon name
    property color progressColor: Appearance.colors.primary
    property real size: 20
    property real strokeWidth: 2

    // Animation properties
    property real animationDuration: 600  // milliseconds

    implicitWidth: size
    implicitHeight: size

    Behavior on value {
        NumberAnimation {
            duration: circularProgress.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            const centerX = width / 2;
            const centerY = height / 2;
            const radius = (Math.min(width, height) / 2) - (strokeWidth / 2);

            ctx.clearRect(0, 0, width, height);

            // Background circle
            ctx.strokeStyle = Appearance.colors.surface_container;
            ctx.lineWidth = strokeWidth;
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
            ctx.stroke();

            // Progress arc
            if (circularProgress.value > 0) {
                ctx.strokeStyle = progressColor;
                ctx.lineWidth = strokeWidth;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                const endAngle = -Math.PI / 2 + (2 * Math.PI * circularProgress.value);
                ctx.arc(centerX, centerY, radius, -Math.PI / 2, endAngle);
                ctx.stroke();
            }
        }
    }

    onValueChanged: canvas.requestPaint()

    // Center icon
    Text {
        anchors.centerIn: parent
        text: icon
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
        text: `${Math.round(circularProgress.value * 100)}%`
    }
}
