pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

import qs.components
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
            // 1px hairline around the screen edge; radius follows the token
            // (sharp in the HUD scheme).
            color: Appearance.colors.outline_variant
            radius: Appearance.rounding.normal
            thickness: 1
        }

        CornerFrame {
            anchors.fill: parent
            armLength: 28
            thickness: 2
            bracketColor: Appearance.colors.primary
        }
    }
}
