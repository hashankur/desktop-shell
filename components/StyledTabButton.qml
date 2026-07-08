import QtQuick
import QtQuick.Controls.Basic

import qs.config

TabButton {
    id: control
    text: qsTr("Button")

    contentItem: Text {
        text: control.text
        font: control.font
        opacity: enabled ? 1.0 : 0.3
        color: control.focus ? Appearance.colors.on_secondary : Appearance.colors.on_surface
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 75
        implicitHeight: 40
        opacity: enabled ? 1 : 0.3
        radius: Appearance.rounding.large
        color: control.focus ? Appearance.colors.secondary : Appearance.colors.surface
    }
}
