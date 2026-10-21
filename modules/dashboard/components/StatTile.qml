pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config

// One readout in the Status strip: tag, big value, optional segment bar
// and two detail lines. Groups are divided by a leading Rule, not a box
// (bar grouping language); the first visible tile turns `divider` off.
RowLayout {
    id: root

    property string title: ""
    property string value: ""
    property string detail: ""
    property string extra: ""
    property real progress: -1
    property bool divider: true
    property color barColor: Appearance.colors.primary

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: 100
    spacing: Appearance.spacing.normal

    Rule {
        vertical: true
        visible: root.divider
        Layout.fillHeight: true
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        HudLabel {
            label: root.title
        }

        StyledText {
            Layout.fillWidth: true
            text: root.value
            mono: true
            elide: Text.ElideRight
            font.pixelSize: Appearance.fontSize.xl
            font.weight: Font.DemiBold
        }

        SegmentBar {
            Layout.fillWidth: true
            visible: root.progress >= 0
            progress: Math.max(0, root.progress)
            barColor: root.barColor
        }

        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.detail
            mono: true
            elide: Text.ElideRight
            color: Appearance.colors.on_surface_variant
            font.pixelSize: Appearance.fontSize.sm
        }

        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.extra
            mono: true
            elide: Text.ElideRight
            color: Appearance.colors.on_surface_variant
            font.pixelSize: Appearance.fontSize.sm
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
