import QtQuick

import qs.components
import qs.services

Item {
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Reference counting: tell SystemStats we're using it
    Component.onCompleted: SystemStats.addRef()
    Component.onDestruction: SystemStats.removeRef()

    Row {
        id: row
        anchors.fill: parent
        spacing: 5

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
            value: SystemStats.gpuUsage
        }

        // Temperature
        CircularProgress {
            anchors.verticalCenter: parent.verticalCenter
            value: SystemStats.temperature
        }
    }
}
