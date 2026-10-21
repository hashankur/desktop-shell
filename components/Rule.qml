import QtQuick

import qs.config

// Shared 1px divider. Horizontal (default): give it `Layout.fillWidth`
// or a width; vertical: set `vertical: true` plus `Layout.fillHeight`
// or a height. The cross axis is always 1px.
Rectangle {
    id: root

    property bool vertical: false

    color: Appearance.colors.outline_variant
    implicitWidth: root.vertical ? 1 : 0
    implicitHeight: root.vertical ? 0 : 1
}
