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
    // Square chip with a full-radius background (a circle in practice).
    property bool circle: false
    // Contextual hover chip. Defaults keep the surface look; override where
    // the surrounding background needs a different accent (e.g. the toast
    // close button on normal vs critical backgrounds).
    property color hoverColor: Appearance.colors.surface_container_high
    property color hoverContentColor: Appearance.colors.on_surface
    property int contentFontSize: Appearance.fontSize.sm

    hoverEnabled: true
    padding: Appearance.padding.larger
    verticalPadding: Appearance.padding.smaller

    contentItem: StyledText {
        text: control.text
        color: control.checked ? Appearance.colors.on_primary_container : (control.hovered ? control.hoverContentColor : Appearance.colors.on_surface)
        font.pixelSize: control.contentFontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    }

    background: Rectangle {
        // Ghost buttons stay invisible until hovered/pressed so icon-only
        // buttons (toast close, mpris, calendar) get the same hover chip.
        visible: !control.ghost || control.hovered || control.down
        radius: control.circle ? Appearance.rounding.full : Appearance.rounding.normal
        color: {
            if (control.checked)
                return Appearance.colors.primary_container;
            if (control.hovered || control.down)
                return control.hoverColor;
            if (control.ghost)
                return "transparent";
            return Appearance.colors.surface_container;
        }
        border.color: control.checked ? Appearance.colors.primary : (control.hovered ? Appearance.colors.outline_variant : "transparent")
        border.width: control.circle ? 0 : 1

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    }
}
