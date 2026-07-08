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
    property var currentMenu: null

    readonly property int trayCount: SystemTray.items.values ? SystemTray.items.values.length : 0

    spacing: 20
    visible: root.trayCount > 0

    Repeater {
        model: SystemTray.items.values

        delegate: TooltipArea {
            id: trayItemRoot
            required property var modelData

            readonly property var trayItem: modelData
            readonly property bool isPassive: trayItemRoot.trayItem.status === Status.Passive
            readonly property bool isAttention: trayItemRoot.trayItem.status === Status.NeedsAttention
            readonly property string iconSource: trayItemRoot.trayItem && trayItemRoot.trayItem.icon ? trayItemRoot.trayItem.icon.toString() : ""

            text: trayItemRoot.trayItem.tooltipTitle || trayItemRoot.trayItem.title || trayItemRoot.trayItem.id || ""

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
                        if (trayItemRoot.trayItem.hasMenu && trayItemRoot.trayItem.menu) {
                            if (root.currentMenu) {
                                root.currentMenu.closeAll();
                                root.currentMenu.destroy();
                            }

                            var mappedPoint = { x: mouse.x, y: mouse.y };
                            if (root.parentWindow && root.parentWindow.contentItem) {
                                mappedPoint = trayItemRoot.mapToItem(root.parentWindow.contentItem, mouse.x, mouse.y);
                            }

                            var menu = trayMenuComponent.createObject(root, {
                                menu: trayItemRoot.trayItem.menu,
                                outputWidth: root.parentWindow ? root.parentWindow.width : 1920,
                                outputHeight: root.parentWindow ? root.parentWindow.height : 1080
                            });
                            root.currentMenu = menu;
                            menu.setPosition(Math.round(mappedPoint.x), Math.round(mappedPoint.y));
                            menu.visible = true;
                            menu.itemTriggered.connect(() => {
                                menu.closeAll();
                                root.currentMenu = null;
                            });
                        } else {
                            trayItemRoot.trayItem.secondaryActivate();
                        }
                    }
                }
            }
        }
    }

    Component {
        id: trayMenuComponent

        TrayMenu {}
    }
}
