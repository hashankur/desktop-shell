pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.components
import qs.config
import qs.services

// Settings overlay: the console's band geometry (same width, same gap under
// the bar) holding configuration pages that do not belong in a transient
// launcher band. Window contract with services/Settings.qml; one overlay at
// a time with the console (see onShownChanged here and there).
OverlayWindow {
    id: root

    enterOffsetY: -40
    screen: Niri.focusedScreen
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusiveZone: 0
    aboveWindows: true
    focusable: true
    color: "transparent"

    property string activePage: "quick"

    // Armed by openPage() before the window maps and dropped once the exit
    // fade unmaps it, so the lazy pages load ahead of the open animation.
    property bool _live: false

    readonly property var tabs: [{
            id: "quick",
            index: "01",
            label: "Quick"
        }, {
            id: "network",
            index: "02",
            label: "Network"
        }, {
            id: "bluetooth",
            index: "03",
            label: "Bluetooth"
        }, {
            id: "appearance",
            index: "04",
            label: "Appearance"
        }]
    readonly property var pageOrder: ["quick", "network", "bluetooth", "appearance"]

    signal closeRequested

    function pageLive(pageId) {
        return root._live && root.activePage === pageId;
    }

    onVisibleChanged: {
        if (!root.visible)
            root._live = false;
    }

    onShownChanged: {
        if (shown) {
            // One overlay at a time.
            Dashboard.close();
            content.forceActiveFocus();
        }
    }

    function openPage(page) {
        // Only a switch while the window is up slides; the open animation
        // already covers the first appearance.
        const dir = Math.sign(root.pageOrder.indexOf(page) - root.pageOrder.indexOf(root.activePage));
        if (root.shown && dir !== 0)
            pages.enter(dir);
        root.activePage = page;
        root._live = true;
        Settings.requestedPage = page;
        content.forceActiveFocus();
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            Settings.toggle();
        }

        function open(): void {
            Settings.open();
        }

        function close(): void {
            Settings.close();
        }

        function openPage(page: string): void {
            Settings.open(page);
        }
    }

    // Kept so existing keybinds keep working; they open the matching page.
    IpcHandler {
        target: "quicksettings"

        function toggle(): void {
            Settings.toggle("quick");
        }

        function open(): void {
            Settings.open("quick");
        }

        function close(): void {
            Settings.close();
        }
    }

    IpcHandler {
        target: "theme"

        function toggle(): void {
            Settings.toggle("appearance");
        }

        function open(): void {
            Settings.open("appearance");
        }

        function close(): void {
            Settings.close();
        }
    }

    Component.onCompleted: Settings.setWindow(root)

    // Click on transparent background to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // FocusScope: the window's focus lands on the scope itself, so the Keys
    // handler receives Esc. A plain Item here competed with focused children
    // on activation (see ConsoleWindow).
    FocusScope {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            }
        }

        Item {
            id: card

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Appearance.barGap
            width: Math.min(980 + Appearance.padding.large * 2, parent.width - Appearance.spacing.large * 2)
            height: column.implicitHeight + Appearance.padding.large * 2
            opacity: root.animOpacity
            transform: Translate {
                y: root.animY
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.surface_container_lowest
                border.width: 1
                border.color: Appearance.colors.outline_variant
                radius: Appearance.rounding.large
            }

            // Prevent clicks inside the card from reaching the backdrop.
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: column

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: parent.width - Appearance.padding.large * 2
                spacing: Appearance.spacing.normal

                BandHeader {
                    Layout.fillWidth: true
                    tabs: root.tabs
                    activePane: root.activePage
                    onSelectPane: pageId => Settings.open(pageId)
                }

                PaneStack {
                    id: pages

                    current: {
                        switch (root.activePage) {
                        case "network":
                            return networkLoader.item;
                        case "bluetooth":
                            return bluetoothLoader.item;
                        case "appearance":
                            return appearanceLoader.item;
                        default:
                            return quickLoader.item;
                        }
                    }

                    Loader {
                        id: quickLoader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: item ? item.implicitHeight : 0
                        visible: active
                        active: root.pageLive("quick")
                        sourceComponent: QuickPage {}
                    }

                    Loader {
                        id: networkLoader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: item ? item.implicitHeight : 0
                        visible: active
                        active: root.pageLive("network")
                        sourceComponent: NetworkPage {}
                    }

                    Loader {
                        id: bluetoothLoader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: item ? item.implicitHeight : 0
                        visible: active
                        active: root.pageLive("bluetooth")
                        sourceComponent: BluetoothPage {}
                    }

                    Loader {
                        id: appearanceLoader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: item ? item.implicitHeight : 0
                        visible: active
                        active: root.pageLive("appearance")
                        sourceComponent: AppearancePage {}
                    }
                }
            }
        }
    }
}
