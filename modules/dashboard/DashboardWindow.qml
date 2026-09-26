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

OverlayWindow {
    id: root

    signal closeRequested

    // Content slides down from above on enter, back up on exit.
    enterOffsetY: -40
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

        function toggle(): void {
            Dashboard.toggle();
        }

        function open(): void {
            Dashboard.open();
        }

        function openView(view: string): void {
            Dashboard.open(view);
        }

        function close(): void {
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
            opacity: root.animOpacity
            transform: Translate {
                y: root.animY
            }

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
                        text: "System"
                        onClicked: root.openView("system")
                    }

                    StyledTabButton {
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

    Component.onCompleted: {
        Dashboard.setWindow(root);
    }
}
