pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.components
import qs.config

// Interactive 0..1 slider row (icon + track). Click/drag on the track
// emits `moved`; clicking the icon emits `iconClicked` (mute toggle).
RowLayout {
    id: root

    property real value: 0.0
    property string iconName: ""
    property bool iconClickable: false

    property bool _dragging: false
    property real _dragVal: 0.0
    readonly property real _shown: _dragging ? _dragVal : value

    signal moved(real value)
    signal iconClicked

    spacing: Appearance.spacing.normal

    Item {
        id: iconWrap
        implicitWidth: 20
        implicitHeight: 20
        Layout.alignment: Qt.AlignVCenter

        Icon {
            id: icon
            anchors.horizontalCenter: iconWrap.horizontalCenter
            source: Quickshell.iconPath(root.iconName, true)
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.iconClickable
            cursorShape: root.iconClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.iconClicked()
        }
    }

    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 24

        ProgressBar {
            id: bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            progress: root._shown
            animationDuration: root._dragging ? 0 : Appearance.anim.durations.small
        }

        Rectangle {
            width: 14
            height: 14
            radius: Appearance.rounding.full
            color: Appearance.colors.primary
            anchors.verticalCenter: bar.verticalCenter
            x: Math.max(0, Math.min(track.width - width, root._shown * track.width - width / 2))
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function valueAt(x) {
                return Math.max(0, Math.min(1, x / track.width));
            }

            onPressed: mouse => {
                root._dragging = true;
                root._dragVal = valueAt(mouse.x);
                root.moved(root._dragVal);
            }
            onPositionChanged: mouse => {
                if (pressed) {
                    root._dragVal = valueAt(mouse.x);
                    root.moved(root._dragVal);
                }
            }
            onReleased: {
                root._dragging = false;
            }
        }
    }
}
