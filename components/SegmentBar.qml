pragma ComponentBehavior: Bound

import QtQuick

import qs.config

// Discrete block progress (battery, volume, brightness). Replaces the
// pill ProgressBar where the language wants boot-segment readouts.
Item {
    id: root

    property real progress: 0.0
    property int segments: 10
    property int gap: 2
    property color barColor: Appearance.colors.primary
    property color trackColor: Appearance.colors.surface_container

    implicitHeight: 10

    Row {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.segments

            Rectangle {
                required property int index

                width: (root.width - root.gap * (root.segments - 1)) / root.segments
                height: root.height
                color: (index < Math.round(root.progress * root.segments)) ? root.barColor : root.trackColor

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.durations.small
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }
        }
    }
}
