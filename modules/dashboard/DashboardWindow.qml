pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.components
import qs.config
import qs.services
import "./components" as DashboardComponents

PanelWindow {
    id: root

    signal closeRequested

    visible: false
    color: "transparent"
    exclusiveZone: 0
    focusable: true
    aboveWindows: true
    screen: Niri.focusedScreen

    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    IpcHandler {
        target: "dashboard"

        function toggle() {
            Dashboard.toggle();
        }

        function open() {
            Dashboard.open();
        }

        function close() {
            Dashboard.close();
        }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onReleased: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            }
        }

        // Click on transparent background to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }

        Rectangle {
            id: frame
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 18
            width: Math.min(980, parent.width - Appearance.spacing.large * 2)
            height: 500
            radius: Appearance.rounding.large
            color: Appearance.colors.surface
            border.color: Appearance.colors.surface_bright
            border.width: 1

            // Prevent clicks inside the frame from closing the dashboard
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: "transparent"
                    }
                    spacing: Appearance.spacing.normal

                    StyledTabButton {
                        text: "Overview"
                        onClicked: root.openView("overview")
                    }

                    StyledTabButton {
                        text: "Media"
                        onClicked: root.openView("mpris")
                    }
                }

                StackLayout {
                    id: viewStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: tabBar.currentIndex

                    Item {
                        RowLayout {
                            anchors.fill: parent
                            spacing: Appearance.spacing.normal

                            DashboardComponents.Calendar {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 400
                            }

                            DashboardComponents.Notifications {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 450
                            }
                        }
                    }

                    Item {
                        DashboardComponents.Mpris {
                            anchors.centerIn: parent
                            width: parent.width
                        }
                    }
                }
            }
        }
    }

    function viewIndexFor(viewName) {
        return viewName === "mpris" ? 1 : 0;
    }

    function applyView(viewName) {
        var normalizedView = viewName === "mpris" ? "mpris" : "overview";
        // tabBar.currentIndex is the single source of truth; viewStack
        // and tab highlighting derive from it via bindings.
        tabBar.currentIndex = viewIndexFor(normalizedView);
    }

    function openView(viewName) {
        applyView(viewName);
    }

    Component.onCompleted: {
        Dashboard.setWindow(root);
    }
}
