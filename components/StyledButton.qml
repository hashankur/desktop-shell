pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic

import qs.config

// Project-styled text button. Use this instead of raw
// QtQuick.Controls.Button so buttons match the Appearance palette,
// rounding, spacing, and fonts.
Button {
    id: control

    // Flat: no background tile (for close/ghost buttons).
    property bool ghost: false

    hoverEnabled: true
    padding: Appearance.padding.larger
    verticalPadding: Appearance.padding.smaller

    contentItem: StyledText {
        text: control.text
        color: control.checked ? Appearance.colors.on_primary_container : Appearance.colors.on_surface
        font.pixelSize: Appearance.fontSize.sm
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        visible: !control.ghost
        radius: Appearance.rounding.normal
        color: {
            if (control.checked)
                return Appearance.colors.primary_container;
            if (control.hovered || control.down)
                return Appearance.colors.surface_container_high;
            return Appearance.colors.surface_container;
        }
        border.color: control.checked ? Appearance.colors.primary : (control.hovered ? Appearance.colors.outline_variant : "transparent")
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.small
            }
        }
    }
}
