import QtQuick.Controls.impl as Impl

import qs.config

Impl.ColorImage {
    sourceSize.width: 14
    sourceSize.height: 14
    anchors.verticalCenter: parent.verticalCenter
    smooth: true
    color: Appearance.colors.on_surface
}
