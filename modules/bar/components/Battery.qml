import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

TooltipArea {
    id: root
    visible: Battery.available
    implicitWidth: batteryRow.implicitWidth
    implicitHeight: 14

    text: getTooltipText()

    // Color based on battery level
    function getBatteryColor() {
        if (Battery.isCharging) {
            return Appearance.colors.primary;
        }
        else if (Battery.percentage >= 0.3) {
            return Appearance.colors.secondary;
        }
        else {
            return Appearance.colors.error;
        }
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

    // Icon {
    //     source: Quickshell.iconPath(UPower.displayDevice.iconName)
    // }

    Row {
        id: batteryRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.spacing.small

        // Row positions children by x only, so this needs its own
        // vertical anchor or it sits flush against the row's top edge.
        SegmentBar {
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            height: 8
            segments: 8
            progress: Battery.percentage
            barColor: root.getBatteryColor()
        }

        HudLabel {
            anchors.verticalCenter: parent.verticalCenter
            label: `${Math.round(Battery.percentage * 100)}%`
        }
    }
}
