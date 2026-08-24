import QtQuick.Effects
import Quickshell.Widgets

import qs.config

IconImage {
    implicitSize: 16
    anchors.verticalCenter: parent.verticalCenter
    layer.enabled: true
    layer.effect: MultiEffect {
        colorization: 0.5
        colorizationColor: Appearance.colors.on_surface
        brightness: 0.5
        contrast: -1.0
    }
}
