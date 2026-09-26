pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services

Item {
    id: root

    // Caelestia-style rows: each row distributes width equally among its
    // visible cards via equal Layout.preferredWidth + fillWidth, so cards
    // never leave holes or size themselves from differing header text.
    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            UsageGraph {
                label: "CPU"
                value: SystemStats.cpuUsage
                history: SystemStats.cpuHistory
                lineColor: Appearance.colors.primary
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 300
            }

            UsageGraph {
                label: "GPU"
                value: SystemStats.gpuUsage
                history: SystemStats.gpuHistory
                available: SystemStats.gpuAvailable
                lineColor: Appearance.colors.secondary
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 300
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            UsageGraph {
                label: "Memory"
                value: SystemStats.memoryUsage
                history: SystemStats.memoryHistory
                lineColor: Appearance.colors.tertiary
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 300
            }

            UsageGraph {
                label: "Temp"
                value: SystemStats.temperature
                history: SystemStats.temperatureHistory
                available: SystemStats.temperatureAvailable
                detail: `${SystemStats.temperatureCelsius.toFixed(0)}°C`
                lineColor: Appearance.colors.error
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 300
            }
        }
    }
}
