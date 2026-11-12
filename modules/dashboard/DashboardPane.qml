pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services
import "./components" as DashboardComponents

// Dashboard pane for the console band. The window shell (IPC, backdrop,
// focus, calendar refresh) lives in modules/console/ConsoleWindow.qml,
// and so do the sub-tab labels: BandHeader draws them from viewLabels.
Item {
    id: root

    implicitHeight: 440

    readonly property var viewLabels: ["Overview", "Status", "Media"]
    // The pane is unloaded while the console is closed or on another pane, so
    // it restores the service's view instead of resetting to Overview.
    property int viewIndex: viewIndexFor(Dashboard.requestedView)

    // The history list lives on Overview, so seeing it (or a toast landing
    // while it is up) clears the bar's unread count.
    readonly property bool listingNotifications: viewIndex === 0
    onListingNotificationsChanged: if (listingNotifications)
        Notifications.markRead()
    Component.onCompleted: if (listingNotifications)
        Notifications.markRead()

    Connections {
        target: Notifications
        function onUnreadCountChanged() {
            if (root.listingNotifications)
                Notifications.markRead();
        }
    }

    // Horizontal pager (caelestia pattern): pages sit side by side and slide
    // to the current one. viewIndex is the single source of truth; pages
    // derive their position from it, so direction-aware travel comes for
    // free. clip hides the neighbours.
    Item {
        id: viewStack
        anchors.fill: parent
        clip: true

        Item {
            width: viewStack.width
            height: viewStack.height
            x: -root.viewIndex * viewStack.width
            enabled: root.viewIndex === 0

            Behavior on x {
                NumberAnimation {
                    duration: Appearance.anim.durations.expressiveFastSpatial
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: Appearance.spacing.normal

                // Capped and centred: spare band width becomes margin instead
                // of stretched day cells.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 470

                    DashboardComponents.Calendar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width, 470)
                        height: parent.height
                    }
                }

                DashboardComponents.Notifications {
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    // The popup width plus room for the scrollbar: rows are exactly
                    // as wide as a toast.
                    Layout.preferredWidth: Notifications.toastWidth + Appearance.spacing.normal
                }
            }
        }

        Item {
            width: viewStack.width
            height: viewStack.height
            x: (1 - root.viewIndex) * viewStack.width
            enabled: root.viewIndex === 1

            Behavior on x {
                NumberAnimation {
                    duration: Appearance.anim.durations.expressiveFastSpatial
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            DashboardComponents.StatusView {
                anchors.fill: parent
                active: root.viewIndex === 1
            }
        }

        Item {
            width: viewStack.width
            height: viewStack.height
            x: (2 - root.viewIndex) * viewStack.width
            enabled: root.viewIndex === 2

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

    function viewIndexFor(viewName) {
        if (viewName === "system")
            return 1;
        if (viewName === "mpris")
            return 2;
        return 0;
    }

    function openView(viewName) {
        const normalized = Dashboard.normalizeView(viewName);
        root.viewIndex = root.viewIndexFor(normalized);
        // Keep the service's requestedView in sync so view-aware toggle works.
        Dashboard.syncView(normalized);
    }
}
