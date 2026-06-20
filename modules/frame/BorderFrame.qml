pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Item {
    id: root

    property color color: "transparent"
    property real radius: 24
    property real thickness: 1
    property real inset: 0

    anchors.fill: parent

    Rectangle {
        id: frame
        anchors.fill: parent
        color: root.color

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: mask
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.thickness
            radius: Math.max(0, root.radius - root.thickness)
        }
    }
}
