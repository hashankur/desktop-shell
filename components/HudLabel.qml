pragma ComponentBehavior: Bound

import QtQuick

import qs.config

// Letterspaced uppercase mono micro-label (section tags, readouts,
// hints). QML Text has no text-transform, so uppercasing lives in the
// binding; pass text through `label`, not `text`.
Text {
    id: root

    property string label: ""
    property bool accent: false

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    text: root.label.toUpperCase()
    color: root.accent ? Appearance.colors.primary : Appearance.colors.on_surface_variant
    font {
        family: Appearance.font.mono
        pixelSize: Appearance.fontSize.xs
        letterSpacing: Appearance.tracking.micro
    }
}
