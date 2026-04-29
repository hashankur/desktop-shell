import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import Quickshell.Services.UPower

import qs.components
import qs.config
import qs.services

Item {
    width: 60
    height: 20

    // Color based on battery level
    function getBatteryColor() {
        if (Battery.isCharging) {
            return Appearance.colors.primary;
        }
        if (Battery.percentage >= 0.5) {
            return Appearance.colors.on_surface;
        }
        if (Battery.percentage >= 0.2) {
            return Appearance.colors.tertiary;
        }
        return Appearance.colors.error; // Red when below 20%
    }

    // Format time in seconds to human readable format
    function formatTime(seconds) {
        if (seconds <= 0)
            return "N/A";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);

        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        }
        return `${minutes}m`;
    }

    // Get tooltip text
    function getTooltipText() {
        let text = `Battery: ${Math.round(Battery.percentage * 100)}%`;

        if (Battery.isCharging) {
            text += `\nCharging`;
            if (Battery.timeToFull > 0) {
                text += `\nTime to full: ${formatTime(Battery.timeToFull)}`;
            }
        } else {
            if (Battery.timeToEmpty > 0) {
                text += `\nTime to empty: ${formatTime(Battery.timeToEmpty)}`;
            }
        }

        return text;
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colors.surface_container

        // Progress indicator
        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                margins: 1
            }
            width: parent.width * Battery.percentage - 2
            radius: Math.min(parent.radius - 1, width / 2) // Fix clipping?
            color: getBatteryColor()

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Battery percentage text
        // Text {
        //     anchors.centerIn: parent
        //     text: `${Math.round(Battery.percentage * 100)}%`
        //     font.family: Appearance.font.mono
        //     font.pixelSize: 10
        //     font.weight: Font.Bold
        //     color: Battery.percentage > 0.5 ? Appearance.colors.on_surface : Appearance.colors.surface
        //     z: 1
        // }
    }

    // Tooltip
    ToolTip {
        visible: mouseArea.containsMouse
        text: getTooltipText()
        delay: 500
        timeout: 5000
        z: 1000

        background: Rectangle {
            color: Appearance.colors.surface_container
            border.color: Appearance.colors.outline
            border.width: 1
            radius: 4
            implicitWidth: 150
            implicitHeight: 40
        }

        contentItem: Text {
            text: getTooltipText()
            color: Appearance.colors.on_surface
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            padding: 8
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }
}
