pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var dashboardWindow: null
    property bool requestedVisible: false
    property string requestedView: "overview"

    function normalizeView(viewName) {
        switch ((viewName || "").toLowerCase()) {
        case "mpris":
        case "music":
            return "mpris";
        case "system":
        case "status":
        case "stats":
            return "system";
        case "calendar":
        case "notifications":
        case "overview":
        default:
            return "overview";
        }
    }

    function syncView(viewName) {
        requestedView = normalizeView(viewName);
    }

    function setWindow(window) {
        dashboardWindow = window;
        if (window) {
            window.closeRequested.connect(function () {
                root.close();
            });
        }
    }

    function open(viewName) {
        requestedView = normalizeView(viewName);
        requestedVisible = true;

        if (dashboardWindow) {
            dashboardWindow.openView(requestedView);
            dashboardWindow.openAnimated();
        }
    }

    function toggle(viewName) {
        if (!viewName) {
            // No view requested (IPC toggle, bar clock): plain open/close.
            // Reopening keeps the last-shown tab: never navigates.
            if (requestedVisible)
                close();
            else
                open(requestedView);
            return;
        }
        // View-aware: switching to the already-open view closes; requesting
        // another view switches tabs instead of dismissing the overlay.
        const target = normalizeView(viewName);
        if (requestedVisible && target === requestedView) {
            close();
        } else {
            open(target);
        }
    }

    function close() {
        requestedVisible = false;
        if (dashboardWindow) {
            dashboardWindow.closeAnimated();
        }
    }
}
