pragma ComponentBehavior: Bound

import QtQuick

import qs.config

// Four corner bracket ticks over a rect (anchors.fill the host). The
// decorative frame language: brackets read as a viewfinder without the
// cost of a full border everywhere.
Item {
    id: root

    property int armLength: 12
    property int thickness: 1
    property color bracketColor: Appearance.colors.outline

    Repeater {
        model: 4

        // Horizontal arms.
        Rectangle {
            required property int index

            width: root.armLength
            height: root.thickness
            x: (index % 2 === 0) ? 0 : root.width - width
            y: (index < 2) ? 0 : root.height - height
            color: root.bracketColor
        }
    }

    Repeater {
        model: 4

        // Vertical arms.
        Rectangle {
            required property int index

            width: root.thickness
            height: root.armLength
            x: (index % 2 === 0) ? 0 : root.width - width
            y: (index < 2) ? 0 : root.height - height
            color: root.bracketColor
        }
    }
}
