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
        case "calendar":
        case "notifications":
        case "overview":
        default:
            return "overview";
        }
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
            dashboardWindow.visible = true;
        }
    }

    function toggle(viewName) {
        if (requestedVisible) {
            close();
        } else {
            open(viewName);
        }
    }

    function close() {
        requestedVisible = false;
        if (dashboardWindow) {
            dashboardWindow.visible = false;
        }
    }
}
