import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config

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

    // Background circle
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
            ctx.strokeStyle = progressColor;
            ctx.lineWidth = strokeWidth;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            // Start from top (-π/2) and go clockwise
            const endAngle = -Math.PI / 2 + (2 * Math.PI * circularProgress.value);
            ctx.arc(centerX, centerY, radius, -Math.PI / 2, endAngle);
            ctx.stroke();
        }
    }

    // Update canvas when value changes
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
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true

        ToolTip {
            visible: mouseArea.containsMouse
            text: `${Math.round(value * 100)}%`
            delay: 300
            timeout: 3000

            background: Rectangle {
                color: Appearance.colors.surface_container
                border.color: Appearance.colors.outline
                border.width: 1
                radius: 4
            }

            contentItem: Text {
                text: `${Math.round(circularProgress.value * 100)}%`
                color: Appearance.colors.on_surface
                font.pixelSize: 11
                padding: 6
            }
        }
    }
}
