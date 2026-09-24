import QtQuick

import qs.components
import qs.services

Item {
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.fill: parent
        spacing: 6

        // CPU
        CircularProgress {
            anchors.verticalCenter: parent.verticalCenter
            value: SystemStats.cpuUsage
        }

        // Memory
        CircularProgress {
            anchors.verticalCenter: parent.verticalCenter
            value: SystemStats.memoryUsage
        }

        // GPU
        CircularProgress {
            anchors.verticalCenter: parent.verticalCenter
            visible: SystemStats.gpuAvailable
            value: SystemStats.gpuUsage
        }

        // Temperature
        CircularProgress {
            anchors.verticalCenter: parent.verticalCenter
            visible: SystemStats.temperatureAvailable
            value: SystemStats.temperature
            tooltipText: `${SystemStats.temperatureCelsius.toFixed(1)}°C`
        }
    }
}
