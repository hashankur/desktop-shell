import QtQuick
import QtQuick.Controls.Basic

import qs.components
import qs.config

TabButton {
    id: control
    text: qsTr("Button")
    hoverEnabled: true
    // Orange index prefix ("01") rendered before the tab label.
    property string indexLabel: ""

    font.family: Appearance.font.mono
    font.letterSpacing: Appearance.tracking.label

    contentItem: Item {
        Row {
            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            HudLabel {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.indexLabel.length > 0
                label: control.indexLabel
                accent: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: control.text.toUpperCase()
                font: control.font
                opacity: enabled ? 1.0 : 0.3
                color: control.checked ? Appearance.colors.on_secondary : Appearance.colors.on_surface
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.durations.small
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
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
