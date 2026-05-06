pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import qs.config
import qs.services
import "./components" as DashboardComponents

PanelWindow {
    id: root

    signal closeRequested

    property int currentViewIndex: 0

    implicitWidth: 980
    implicitHeight: 660
    visible: false
    color: "transparent"
    focusable: true
    exclusiveZone: 0
    screen: Quickshell.screens[0]
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    Item {
        anchors.fill: parent

        Rectangle {
            id: frame
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 18
            width: Math.min(980, parent.width - Appearance.spacing.large * 2)
            height: 660
            radius: Appearance.rounding.large
            color: Appearance.colors.surface_container_lowest
            border.color: Appearance.colors.surface_container
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.normal

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Dashboard"
                        color: Appearance.colors.on_surface
                        font.family: Appearance.font.sans
                        font.pixelSize: Appearance.fontSize.large
                        font.weight: Font.Medium
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Close"
                        onClicked: root.closeRequested()
                    }
                }

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    currentIndex: root.currentViewIndex

                    TabButton {
                        text: "Overview"
                        onClicked: root.openView("overview")
                    }

                    TabButton {
                        text: "MPRIS"
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

                            DashboardComponents.DashboardCalendar {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 390
                            }

                            DashboardComponents.DashboardNotifications {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 470
                            }
                        }
                    }

                    Item {
                        DashboardComponents.DashboardMpris {
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
        var newIndex = viewIndexFor(normalizedView);

        currentViewIndex = newIndex;
        tabBar.currentIndex = newIndex;
        viewStack.currentIndex = newIndex;
    }

    function openView(viewName) {
        applyView(viewName);
    }

    Keys.onReleased: function (event) {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        Dashboard.setWindow(root);
    }
}
