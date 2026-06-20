pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs.config
import qs.components

PanelWindow {
    id: root

    property var menu: null
    property int entryHeight: 36
    property int horizontalPadding: 12
    property int outputWidth: 1920
    property int outputHeight: 1080

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    color: "transparent"
    aboveWindows: true
    focusable: false
    visible: false

    signal itemTriggered

    QtObject {
        id: d
        property var submenu: null
        property var hoveredEntry: null
        property Component subComp: null

        property int xPos: 0
        property int yPos: 0
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.menu
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.closeAll()
        onWheel: root.closeAll()
    }

    Item {
        x: d.xPos
        y: d.yPos
        width: 220
        height: listContainer.height

        Rectangle {
            id: listContainer
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colors.surface_container_high
            border.color: "red"
            border.width: 10

            Column {
                anchors.fill: parent
                anchors.margins: 4

                Repeater {
                    model: menuOpener.children

                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        readonly property var entry: modelData

                        width: listContainer.width - 8
                        height: entry.isSeparator ? 8 : root.entryHeight
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.surface_container

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: {
                                if (!delegateRoot.entry.enabled)
                                    return "transparent";
                                if (d.hoveredEntry === delegateRoot.entry)
                                    return Appearance.colors.surface_container_high;
                                return "transparent";
                            }
                            opacity: delegateRoot.entry.enabled ? 1.0 : 0.4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.horizontalPadding
                                anchors.rightMargin: root.horizontalPadding
                                spacing: 8

                                Item {
                                    id: checkBox
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    visible: delegateRoot.entry.buttonType !== 0

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: delegateRoot.entry.buttonType === 2 ? 8 : 3
                                        color: "transparent"
                                        border.color: Appearance.colors.on_surface_variant
                                        border.width: 1

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 10
                                            height: 10
                                            radius: delegateRoot.entry.buttonType === 2 ? 5 : 2
                                            color: Appearance.colors.primary
                                            visible: delegateRoot.entry.checkState === Qt.Checked
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 6
                                            height: 6
                                            radius: delegateRoot.entry.buttonType === 2 ? 3 : 1
                                            color: Appearance.colors.on_surface_variant
                                            visible: delegateRoot.entry.checkState === Qt.PartiallyChecked
                                        }
                                    }
                                }

                                Item {
                                    id: iconContainer
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    visible: delegateRoot.entry.icon !== "" && delegateRoot.entry.icon !== undefined

                                    IconImage {
                                        anchors.fill: parent
                                        source: delegateRoot.entry.icon
                                    }
                                }

                                StyledText {
                                    id: label
                                    Layout.fillWidth: true
                                    text: delegateRoot.entry.text || ""
                                    font.pixelSize: Appearance.fontSize.sm
                                    color: Appearance.colors.on_surface
                                    elide: Text.ElideRight
                                }

                                Item {
                                    Layout.preferredWidth: delegateRoot.entry.hasChildren ? 16 : 0
                                    Layout.preferredHeight: 16
                                    visible: delegateRoot.entry.hasChildren

                                    Text {
                                        anchors.centerIn: parent
                                        text: "▶"
                                        font.pixelSize: 10
                                        color: Appearance.colors.on_surface_variant
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: delegateRoot.entry.enabled && !delegateRoot.entry.isSeparator

                                onClicked: {
                                    delegateRoot.entry.triggered();
                                    root.itemTriggered();
                                }

                                onEntered: {
                                    d.hoveredEntry = delegateRoot.entry;
                                    if (delegateRoot.entry.hasChildren) {
                                        showSubmenu(delegateRoot.entry, delegateRoot);
                                    } else {
                                        closeSubmenu();
                                    }
                                }

                                onExited: {
                                    if (d.hoveredEntry === delegateRoot.entry) {
                                        d.hoveredEntry = null;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: root.horizontalPadding
                            anchors.rightMargin: root.horizontalPadding
                            height: 1
                            color: Appearance.colors.outline_variant
                            visible: delegateRoot.entry.isSeparator
                        }
                    }
                }
            }
        }
    }

    function showSubmenu(entry, delegateItem) {
        closeSubmenu();

        if (!d.subComp) {
            d.subComp = Qt.createComponent("TrayMenu.qml");
        }

        if (d.subComp.status !== Component.Ready)
            return;

        var globalPos = delegateItem.mapToItem(root.contentItem, delegateItem.width, 0);
        var sub = d.subComp.createObject(root, {
            menu: entry,
            outputWidth: root.outputWidth,
            outputHeight: root.outputHeight
        });
        sub.setPosition(Math.round(globalPos.x), Math.round(globalPos.y));
        sub.visible = true;

        sub.itemTriggered.connect(() => {
            root.itemTriggered();
            closeAll();
        });

        d.submenu = sub;
    }

    function setPosition(x, y) {
        var menuWidth = 220;
        var menuHeight = listContainer.height || (menuOpener.children.length * root.entryHeight + 8);

        if (x + menuWidth > root.outputWidth)
            x = root.outputWidth - menuWidth - 8;
        if (y + menuHeight > root.outputHeight)
            y = root.outputHeight - menuHeight - 8;
        if (x < 0)
            x = 8;
        if (y < 0)
            y = 8;

        d.xPos = Math.round(x);
        d.yPos = Math.round(y);
    }

    function closeSubmenu() {
        if (d.submenu) {
            d.submenu.visible = false;
            d.submenu.destroy();
            d.submenu = null;
        }
    }

    function closeAll() {
        closeSubmenu();
        root.visible = false;
    }

    onVisibleChanged: {
        if (!visible) {
            closeSubmenu();
        }
    }
}
