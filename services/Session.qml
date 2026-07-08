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
            powerMenuWindow.visible = true;
        }
    }

    function close() {
        requestedVisible = false;
        if (powerMenuWindow) {
            powerMenuWindow.visible = false;
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
