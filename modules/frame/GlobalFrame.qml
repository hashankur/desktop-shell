pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

import qs.config

Variants {
    model: Quickshell.screens

    PanelWindow {
        required property ShellScreen modelData

        screen: modelData
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        focusable: false
        exclusiveZone: 0
        color: "transparent"
        mask: Region {}

        BorderFrame {
            anchors.fill: parent
            anchors.topMargin: 44
            color: Appearance.colors.surface_container_lowest
            radius: 20 // Inner radius + spacing
            thickness: 0
        }
    }
}
