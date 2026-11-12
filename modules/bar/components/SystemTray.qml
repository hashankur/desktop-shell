pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

import qs.components
import qs.config

// The tray stays collapsed to a section tag ("TRAY", same vocabulary as
// NET/PWR); hovering the block expands the icon row inline in the bar.
Item {
    id: root

    property var parentWindow
    property var currentMenu: null
    // Controlled by the bar: false hides the tray on non-primary outputs.
    property bool activeOnScreen: true

    readonly property int trayCount: SystemTray.items.values ? SystemTray.items.values.length : 0
    readonly property var trayScreen: parentWindow && parentWindow.screen ? parentWindow.screen : null
    readonly property bool expanded: hoverHandler.hovered

    height: 14
    visible: root.trayCount > 0 && root.activeOnScreen
    width: trayTag.implicitWidth + (root.expanded ? Appearance.spacing.normal + iconsRow.implicitWidth : 0)
    clip: true

    Behavior on width {
        NumberAnimation {
            duration: Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    // Hovering the tag OR any revealed icon keeps the block open; the
    // icons themselves are outside the collapsed rect, so the block
    // only closes when the pointer leaves the whole thing.
    HoverHandler {
        id: hoverHandler
    }

    HudLabel {
        id: trayTag
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        label: "TRAY"
        accent: root.expanded
    }

    Row {
        id: iconsRow
        anchors.left: trayTag.right
        anchors.leftMargin: Appearance.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20

        Repeater {
            model: SystemTray.items.values

            delegate: Item {
                id: trayItemRoot
                required property var modelData

                readonly property var trayItem: modelData
                readonly property string iconSource: trayItemRoot.trayItem && trayItemRoot.trayItem.icon ? trayItemRoot.trayItem.icon.toString() : ""

                // explicit implicits: Item defaults them to 0, and the
                // collapsed/expanded width math reads iconsRow.implicitWidth.
                implicitWidth: 14
                implicitHeight: 14
                width: 14
                height: 14

                IconImage {
                    anchors.fill: parent
                    visible: trayItemRoot.iconSource !== ""
                    source: trayItemRoot.iconSource
                }

                // Gated while collapsed: the icons are clipped out of the
                // block but must not stay clickable outside its rect.
                MouseArea {
                    anchors.fill: parent
                    enabled: root.expanded
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
                                // clears currentMenu, so no manual null-out is needed.
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
    }

    Component {
        id: trayMenuComponent

        TrayMenu {}
    }
}
