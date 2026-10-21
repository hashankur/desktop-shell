import QtQuick

import qs.config

Text {
    id: root

    // Mono-first shell: data, labels and UI text ride Iosevka; only
    // display-scale titles opt out via the default sans.
    property bool mono: false

    color: Appearance.colors.on_surface
    font {
        family: root.mono ? Appearance.font.mono : Appearance.font.sans
        pixelSize: Appearance.fontSize.base
    }
}
