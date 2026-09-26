import QtQuick
import QtQuick.Controls.Basic

import qs.config

TabButton {
    id: control
    text: qsTr("Button")
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font: control.font
        opacity: enabled ? 1.0 : 0.3
        color: control.checked ? Appearance.colors.on_secondary : Appearance.colors.on_surface
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
        implicitWidth: 75
        implicitHeight: 40
        opacity: enabled ? 1 : 0.3
        radius: Appearance.rounding.large
        color: control.checked ? Appearance.colors.secondary : (control.hovered ? Appearance.colors.surface_container_high : Appearance.colors.surface)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    }
}
