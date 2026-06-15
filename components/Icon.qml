// import QtQuick.Controls.impl as Impl
import QtQuick.Effects
import Quickshell.Widgets

import qs.config

// Impl.ColorImage {
//     sourceSize.width: 16
//     sourceSize.height: 16
//     anchors.verticalCenter: parent.verticalCenter
//     color: Appearance.colors.on_surface
//     mipmap: true
// }

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
