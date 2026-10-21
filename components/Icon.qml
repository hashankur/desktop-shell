import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

import qs.config

IconImage {
    id: root

    // Symbolic glyphs are half-tinted toward `tint` by default. Icons
    // sitting on an inverted paper chip pass tint + tintAmount: 1, since
    // a 0.5 blend leaves white in the result and washes out on paper.
    property color tint: Appearance.colors.on_surface
    property real tintAmount: 0.5

    // Layout-managed instances opt out: anchors on a RowLayout child are
    // undefined behavior and spam the log (Layout.alignment carries them).
    property bool centerVertically: true

    implicitSize: 16
    anchors.verticalCenter: centerVertically ? parent.verticalCenter : undefined
    layer.enabled: visible && width > 0
    layer.effect: MultiEffect {
        colorization: root.tintAmount
        colorizationColor: root.tint
        brightness: 0.5
        contrast: -1.0
    }
}
