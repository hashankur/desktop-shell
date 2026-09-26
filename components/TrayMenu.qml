pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
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
    readonly property int menuWidth: 220
    property int outputWidth: 1920
    property int outputHeight: 1080

    // In-place libadwaita-style drill-down: submenus are opened by click
    // only (never hover) and replace this window's content; the back header
    // row pops one level via navHistory.
    property var navMenu: menu
    property var navHistory: []
    property string navTitle: ""

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
    // Emitted synchronously just before this menu self-destructs; QML JS
    // cannot observe the C++ `destroyed` signal, so owners use this to
    // drop their references safely.
    signal willDestroy

    QtObject {
        id: d
        property var hoveredEntry: null

        property int rawX: 0
        property int rawY: 0
        property int xPos: 0
        property int yPos: 0

        property real slideX: 0
    }

    // Shared 1px divider: under the back header and between entries.
    component Hairline: Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        height: 1
        color: Appearance.colors.outline_variant
    }

    property var _navCommit: null
    property real _navOut: 0
    property real _navIn: 0

    // Two openers: rootOpener pins the root handle for the window's
    // lifetime. Reassigning a single opener to a submenu entry would
    // unref the root handle (refcount 0 -> deleteLater), destroying the
    // very menu the entry belongs to and leaving the submenu empty.
    // subOpener only refs entries while drilled, which also sends the
    // dbusmenu "opened" event apps need to populate submenu children.
    QsMenuOpener {
        id: rootOpener
        menu: root.menu
    }

    QsMenuOpener {
        id: subOpener
        menu: root.navHistory.length > 0 ? root.navMenu : null
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        // Touchpad scroll can land outside the list and would otherwise
        // close the menu mid-scroll; only close on true outside input.
        onClicked: if (!menuHover.hovered) root.closeAll()
        onWheel: if (!menuHover.hovered) root.closeAll()
    }

    Rectangle {
        id: listContainer
        x: d.xPos
        y: d.yPos
        width: root.menuWidth
        // Size from content: sizing the parent off this rectangle while it
        // fills that parent is a binding loop and collapses the background.
        // Capped to the output with a 8px margin so long menus scroll
        // instead of running off the screen.
        height: Math.min(contentCol.implicitHeight + 8, root.outputHeight - 16)
        radius: Appearance.rounding.normal
        color: Appearance.colors.surface_container
        clip: true

        // Re-clamp whenever content height changes: children load from
        // D-Bus asynchronously, so the menu can grow/shrink after the
        // initial setPosition().
        onHeightChanged: root.clampPosition()

        HoverHandler {
            id: menuHover
        }

        Item {
            x: d.slideX
            width: parent.width
            height: parent.height

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                contentWidth: width
                contentHeight: contentCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Column {
                    id: contentCol
                    width: flick.width

                    Rectangle {
                        visible: root.navHistory.length > 0
                        width: contentCol.width
                        height: root.entryHeight
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: backMouse.containsMouse ? Appearance.colors.surface_container_high : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.horizontalPadding
                            anchors.rightMargin: root.horizontalPadding
                            spacing: 8

                            IconImage {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: Quickshell.iconPath("go-previous-symbolic")
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.navTitle
                                font.pixelSize: Appearance.fontSize.sm
                                font.weight: Font.Medium
                                color: Appearance.colors.on_surface
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: backMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.navigateBack()
                        }
                    }

                    Rectangle {
                        visible: root.navHistory.length > 0
                        width: contentCol.width
                        height: 8
                        color: "transparent"

                        Hairline {}
                    }

                    Repeater {
                        model: root.navHistory.length > 0 ? subOpener.children : rootOpener.children

                        delegate: Rectangle {
                            id: delegateRoot
                            required property var modelData
                            readonly property var entry: modelData

                            width: contentCol.width
                            height: entry.isSeparator ? 8 : root.entryHeight
                            // The container provides the unified background; entries
                            // only paint their hover/checked state on top.
                            color: "transparent"

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
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        visible: delegateRoot.entry.icon !== "" && delegateRoot.entry.icon !== undefined

                                        IconImage {
                                            anchors.fill: parent
                                            source: delegateRoot.entry.icon
                                        }
                                    }

                                    StyledText {
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
                                        if (delegateRoot.entry.hasChildren) {
                                            root.navigateInto(delegateRoot.entry);
                                        } else {
                                            delegateRoot.entry.triggered();
                                            root.itemTriggered();
                                        }
                                    }

                                    onEntered: d.hoveredEntry = delegateRoot.entry

                                    onExited: {
                                        if (d.hoveredEntry === delegateRoot.entry) {
                                            d.hoveredEntry = null;
                                        }
                                    }
                                }
                            }

                            Hairline {
                                visible: delegateRoot.entry.isSeparator
                            }
                        }
                    }
                }
            }
        }
    }

    function _navState() {
        return {
            menu: root.navMenu,
            title: root.navTitle
        };
    }

    function _transition(commit, forward) {
        root._navCommit = commit;
        root._navOut = (forward ? -1 : 1) * listContainer.width;
        root._navIn = (forward ? 1 : -1) * listContainer.width;
        navAnim.restart();
    }

    function navigateInto(entry) {
        d.hoveredEntry = null;
        root._transition(() => {
            root.navHistory = root.navHistory.concat([root._navState()]);
            root.navTitle = entry.text || "";
            root.navMenu = entry;
        }, true);
    }

    function navigateBack() {
        if (root.navHistory.length === 0)
            return;
        d.hoveredEntry = null;
        root._transition(() => {
            const prev = root.navHistory[root.navHistory.length - 1];
            root.navHistory = root.navHistory.slice(0, -1);
            root.navTitle = prev.title;
            root.navMenu = prev.menu;
        }, false);
    }

    SequentialAnimation {
        id: navAnim

        NumberAnimation {
            target: d
            property: "slideX"
            to: root._navOut
            duration: Math.round(Appearance.anim.durations.small * 0.7)
            easing.bezierCurve: Appearance.anim.curves.standardAccel
        }

        ScriptAction {
            script: {
                if (root._navCommit) {
                    root._navCommit();
                    root._navCommit = null;
                }
                flick.contentY = 0;
            }
        }

        NumberAnimation {
            target: d
            property: "slideX"
            from: root._navIn
            to: 0
            duration: Math.round(Appearance.anim.durations.small * 0.7)
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    function setPosition(x, y) {
        d.rawX = Math.round(x);
        d.rawY = Math.round(y);
        clampPosition();
    }

    function clampPosition() {
        var x = d.rawX;
        var y = d.rawY;

        if (x + root.menuWidth > root.outputWidth)
            x = root.outputWidth - root.menuWidth - 8;
        if (y + listContainer.height > root.outputHeight)
            y = root.outputHeight - listContainer.height - 8;
        if (x < 0)
            x = 8;
        if (y < 0)
            y = 8;

        d.xPos = Math.round(x);
        d.yPos = Math.round(y);
    }

    function closeAll() {
        root.visible = false;
    }

    onVisibleChanged: {
        if (!visible) {
            // Fullscreen overlay windows are expensive; owners drop their
            // reference on close, so free ourselves instead of leaking until
            // the next open.
            root.willDestroy();
            Qt.callLater(() => root.destroy());
        }
    }
}
