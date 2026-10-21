pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services
import "./components" as DashboardComponents

// Dashboard pane for the console band. The window shell (IPC, backdrop,
// focus, calendar refresh) lives in modules/console/ConsoleWindow.qml.
Item {
    id: root

    implicitHeight: 500

    ColumnLayout {
        anchors.fill: parent
        // No internal inset: the band card already pads by padding.large,
        // so pane content lines up with the BandHeader tabs above. (A second
        // margin here staggered the calendar 15px right of the header row.)
        // Explicit: the QML default (5) clashed with the 12/15 rhythm
        // used everywhere inside the pages.
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            HudLabel {
                label: "DASHBOARD"
            }

            Rule {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            HudLabel {
                accent: true
                label: tabBar.currentIndex === 0 ? "Overview" : (tabBar.currentIndex === 1 ? "System" : "Media")
            }
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            background: Rectangle {
                color: "transparent"
            }
            spacing: Appearance.spacing.normal

            StyledTabButton {
                indexLabel: "01"
                text: "Overview"
                onClicked: root.openView("overview")
            }

            StyledTabButton {
                indexLabel: "02"
                text: "System"
                onClicked: root.openView("system")
            }

            StyledTabButton {
                indexLabel: "03"
                text: "Media"
                onClicked: root.openView("mpris")
            }
        }

        Item {
            id: viewStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Horizontal pager (caelestia pattern): pages sit side
            // by side and slide to the current one. tabBar.currentIndex
            // stays the single source of truth (see syncView); pages
            // derive their position from it, so direction-aware travel
            // comes for free. clip hides the neighbours.
            property int currentIndex: tabBar.currentIndex
            clip: true

            Item {
                id: pageOverview
                width: viewStack.width
                height: viewStack.height
                x: -viewStack.currentIndex * viewStack.width
                enabled: viewStack.currentIndex === 0

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.durations.expressiveFastSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }

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
                id: pageSystem
                width: viewStack.width
                height: viewStack.height
                x: (1 - viewStack.currentIndex) * viewStack.width
                enabled: viewStack.currentIndex === 1

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.durations.expressiveFastSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }

                DashboardComponents.SystemOverview {
                    anchors.fill: parent
                }
            }

            Item {
                id: pageMedia
                width: viewStack.width
                height: viewStack.height
                x: (2 - viewStack.currentIndex) * viewStack.width
                enabled: viewStack.currentIndex === 2

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.durations.expressiveFastSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }

                DashboardComponents.Mpris {
                    anchors.fill: parent
                }
            }
        }
    }

    function viewIndexFor(viewName) {
        if (viewName === "system")
            return 1;
        if (viewName === "mpris")
            return 2;
        return 0;
    }

    function applyView(viewName) {
        var normalizedView = Dashboard.normalizeView(viewName);
        // tabBar.currentIndex is the single source of truth; viewStack
        // and tab highlighting derive from it via bindings. Keep the
        // service's requestedView in sync so view-aware toggle works.
        tabBar.currentIndex = viewIndexFor(normalizedView);
        Dashboard.syncView(normalizedView);
    }

    function openView(viewName) {
        applyView(viewName);
    }
}
