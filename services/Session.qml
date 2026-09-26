pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var powerMenuWindow: null
    property bool requestedVisible: false

    function setWindow(window) {
        powerMenuWindow = window;
    }

    function open() {
        requestedVisible = true;
        if (powerMenuWindow) {
            powerMenuWindow.openAnimated();
        }
    }

    function close() {
        requestedVisible = false;
        if (powerMenuWindow) {
            powerMenuWindow.closeAnimated();
        }
    }

    function toggle() {
        if (requestedVisible) {
            close();
        } else {
            open();
        }
    }
}
