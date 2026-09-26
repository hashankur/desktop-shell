pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var window: null
    property bool requestedVisible: false

    function setWindow(w) {
        window = w;
        if (w) {
            w.closeRequested.connect(function () {
                root.close();
            });
        }
    }

    function open() {
        requestedVisible = true;
        if (window)
            window.openAnimated();
    }

    function close() {
        requestedVisible = false;
        if (window)
            window.closeAnimated();
    }

    function toggle() {
        if (requestedVisible)
            close();
        else
            open();
    }
}
