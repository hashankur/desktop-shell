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
    // Controlled by the bar: false hides the tray on non-primary outputs.
    property bool activeOnScreen: true

    readonly property int trayCount: SystemTray.items.values ? SystemTray.items.values.length : 0
    readonly property var trayScreen: parentWindow && parentWindow.screen ? parentWindow.screen : null

    spacing: 20
    visible: root.trayCount > 0 && root.activeOnScreen

    Repeater {
        model: SystemTray.items.values

        delegate: TooltipArea {
            id: trayItemRoot
            required property var modelData

            readonly property var trayItem: modelData
            readonly property string iconSource: trayItemRoot.trayItem && trayItemRoot.trayItem.icon ? trayItemRoot.trayItem.icon.toString() : ""

            text: trayItemRoot.trayItem ? (trayItemRoot.trayItem.tooltipTitle || trayItemRoot.trayItem.title || trayItemRoot.trayItem.id || "") : ""

            width: 16
            height: 16

            IconImage {
                anchors.fill: parent
                visible: trayItemRoot.iconSource !== ""
                source: trayItemRoot.iconSource
            }

            MouseArea {
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
                            // closeAll() fires willDestroy synchronously, which
                            // clears currentMenu — no manual null-out needed.
                            if (root.currentMenu)
                                root.currentMenu.closeAll();

                            var mappedPoint = { x: mouse.x, y: mouse.y };
                            if (root.parentWindow && root.parentWindow.contentItem) {
                                mappedPoint = trayItemRoot.mapToItem(root.parentWindow.contentItem, mouse.x, mouse.y);
                            }

                            var props = {
                                menu: trayItemRoot.trayItem.menu,
                                // Screen dims, not window dims: the bar window
                                // is ~40px tall, which broke the menu's
                                // flip-up/clamp math and cut off long menus.
                                outputWidth: root.trayScreen ? root.trayScreen.width : 1920,
                                outputHeight: root.trayScreen ? root.trayScreen.height : 1080
                            };
                            // Open on the output the bar lives on, not the
                            // primary one.
                            if (root.trayScreen)
                                props.screen = root.trayScreen;

                            var menu = trayMenuComponent.createObject(root, props);
                            if (!menu) {
                                console.warn("SystemTray: failed to create tray menu");
                                return;
                            }
                            root.currentMenu = menu;
                            menu.setPosition(Math.round(mappedPoint.x), Math.round(mappedPoint.y));
                            menu.openAnimated();
                            menu.itemTriggered.connect(() => menu.closeAll());
                            // The menu destroys itself when hidden; clear the
                            // reference so the next open doesn't touch a
                            // destroyed object. (`destroyed` isn't visible to
                            // QML JS, so the menu announces it itself.)
                            menu.willDestroy.connect(() => {
                                if (root.currentMenu === menu)
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
