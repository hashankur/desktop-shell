pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

import qs.components
import qs.config

Row {
    id: root

    property var parentWindow

    readonly property int trayCount: SystemTray.items.values ? SystemTray.items.values.length : 0

    spacing: 20
    visible: root.trayCount > 0

    Repeater {
        model: SystemTray.items.values

        delegate: Item {
            id: trayItemRoot
            required property var modelData

            readonly property var trayItem: modelData
            readonly property bool isPassive: trayItemRoot.trayItem.status === Status.Passive
            readonly property bool isAttention: trayItemRoot.trayItem.status === Status.NeedsAttention
            readonly property string iconSource: trayItemRoot.trayItem && trayItemRoot.trayItem.icon ? trayItemRoot.trayItem.icon.toString() : ""

            width: 16
            height: 16
            // visible: !isPassive || isAttention

            IconImage {
                anchors.fill: parent
                visible: trayItemRoot.iconSource !== ""
                source: trayItemRoot.iconSource
            }

            MouseArea {
                id: trayMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        trayItemRoot.trayItem.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayItemRoot.trayItem.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton) {
                        // Show the tray item's menu if available. Map click to window coordinates.
                        if (trayItemRoot.trayItem.hasMenu || trayItemRoot.trayItem.menu) {
                            try {
                                var displayX = mouse.x;
                                var displayY = mouse.y;

                                if (root.parentWindow && root.parentWindow.contentItem) {
                                    var mappedPoint = trayItemRoot.mapToItem(root.parentWindow.contentItem, mouse.x, mouse.y);
                                    displayX = mappedPoint.x;
                                    displayY = mappedPoint.y;
                                }

                                trayItemRoot.trayItem.display(root.parentWindow, displayX, displayY);
                            } catch (e) {
                                // Fallback: call secondaryActivate if display is not available
                                trayItemRoot.trayItem.secondaryActivate();
                            }
                        } else {
                            trayItemRoot.trayItem.secondaryActivate();
                        }
                    }
                }
            }

            // ToolTip {
            //     visible: trayMouseArea.containsMouse
            //     text: trayItemRoot.trayItem.tooltipTitle || trayItemRoot.trayItem.title || trayItemRoot.trayItem.id
            // }
        }
    }
}
