import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

Item {
    implicitWidth: 16
    implicitHeight: 16

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

    // ProgressBar {
    //     anchors.fill: parent
    //     progress: Battery.percentage
    //     barColor: getBatteryColor()
    //     backgroundColor: Appearance.colors.surface_container
    //     animationDuration: 300
    // }

    Icon{
        source: Quickshell.iconPath(UPower.displayDevice.iconName)
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
