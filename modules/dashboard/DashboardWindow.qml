pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import qs.components
import qs.config
import qs.services
import "./components" as DashboardComponents

PanelWindow {
    id: root

    signal closeRequested

    property int currentViewIndex: 0

    visible: false
    color: "transparent"
    exclusiveZone: 0
    screen: Quickshell.screens[0]

    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

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

        Rectangle {
            id: frame
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 18
            width: Math.min(980, parent.width - Appearance.spacing.large * 2)
            height: 500
            radius: Appearance.rounding.large
            color: Appearance.colors.surface_container_lowest
            border.color: Appearance.colors.surface_container
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.large

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    currentIndex: root.currentViewIndex
                    background: Rectangle {
                        color: "transparent"
                    }

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
        var newIndex = viewIndexFor(normalizedView);

        currentViewIndex = newIndex;
        tabBar.currentIndex = newIndex;
        viewStack.currentIndex = newIndex;
    }

    function openView(viewName) {
        applyView(viewName);
    }

    Component.onCompleted: {
        Dashboard.setWindow(root);
    }
}
