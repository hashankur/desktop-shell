pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

Item {
    id: root

    // Formats seconds as m:ss or h:mm:ss.
    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        if (h > 0)
            return `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
        return `${m}:${String(sec).padStart(2, "0")}`;
    }

    function batteryColor() {
        if (Battery.isCharging)
            return Appearance.colors.primary;
        if (Battery.percentage >= 0.3)
            return Appearance.colors.secondary;
        return Appearance.colors.error;
    }

    function batteryStateText() {
        if (Battery.isCharging)
            return Battery.timeToFull > 0 ? `Charging · ${root.formatTime(Battery.timeToFull)} to full` : "Charging";
        if (Battery.isFullyCharged)
            return "Fully charged";
        if (Battery.timeToEmpty > 0)
            return `${root.formatTime(Battery.timeToEmpty)} remaining`;
        return "Discharging";
    }

    component StatCard: ColumnLayout {
        id: card

        property string label: ""
        property real value: 0
        property string detail: `${Math.round(card.value * 100)}%`
        property bool available: true

        visible: available
        spacing: Appearance.spacing.normal

        CircularProgress {
            size: 110
            strokeWidth: 8
            value: card.value
            tooltipText: `${card.label}: ${card.detail}`
            Layout.alignment: Qt.AlignHCenter
        }

        StyledText {
            text: card.label
            font.pixelSize: Appearance.fontSize.base
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        StyledText {
            text: card.detail
            color: Appearance.colors.on_surface_variant
            font.pixelSize: Appearance.fontSize.sm
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.large

        Grid {
            columns: 2
            spacing: Appearance.spacing.normal
            Layout.alignment: Qt.AlignVCenter

            StatCard {
                label: "CPU"
                value: SystemStats.cpuUsage
            }

            StatCard {
                label: "Memory"
                value: SystemStats.memoryUsage
            }

            StatCard {
                label: "GPU"
                value: SystemStats.gpuUsage
                available: SystemStats.gpuAvailable
            }

            StatCard {
                label: "Temp"
                value: SystemStats.temperature
                available: SystemStats.temperatureAvailable
                detail: `${SystemStats.temperatureCelsius.toFixed(0)}°C`
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 280
            radius: Appearance.rounding.normal
            color: Appearance.colors.surface_container

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.normal

                StyledText {
                    text: "Battery"
                    font.pixelSize: Appearance.fontSize.lg
                    font.weight: Font.DemiBold
                }

                StyledText {
                    visible: !Battery.available
                    text: "No battery detected"
                    color: Appearance.colors.on_surface_variant
                    font.pixelSize: Appearance.fontSize.sm
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                ColumnLayout {
                    visible: Battery.available
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    StyledText {
                        text: `${Math.round(Battery.percentage * 100)}%`
                        font.pixelSize: Appearance.fontSize.xxxl
                        font.weight: Font.Black
                        Layout.alignment: Qt.AlignHCenter
                    }

                    StyledText {
                        text: root.batteryStateText()
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.sm
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        progress: Battery.percentage
                        barColor: root.batteryColor()
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: `${Math.abs(Battery.energyRate).toFixed(1)} W`
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: Appearance.fontSize.xs
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: Battery.isCharging ? "Charging" : "On battery"
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: Appearance.fontSize.xs
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
