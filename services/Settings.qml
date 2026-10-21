pragma Singleton

import QtQuick
import Quickshell

// Window contract for SettingsWindow (modules/settings): the window
// registers itself, callers go through open/toggle/close so the
// requestedVisible flag stays the single answer to "is it open".
Singleton {
    id: root

    readonly property var pages: ["quick", "network", "bluetooth", "appearance"]

    property var window: null
    property bool requestedVisible: false
    property string requestedPage: "quick"

    function normalizePage(page) {
        return root.pages.indexOf(page) >= 0 ? page : root.requestedPage;
    }

    function setWindow(w) {
        window = w;
        if (w) {
            w.closeRequested.connect(function () {
                root.close();
            });
        }
    }

    function open(page) {
        requestedPage = normalizePage(page);
        requestedVisible = true;
        if (window) {
            window.openPage(requestedPage);
            window.openAnimated();
        }
    }

    function close() {
        requestedVisible = false;
        if (window)
            window.closeAnimated();
    }

    // With a page: switching to the already-open page closes, another page
    // switches in place. Without one: plain open/close on the last page.
    function toggle(page) {
        if (requestedVisible && (!page || page === requestedPage)) {
            close();
        } else {
            open(page);
        }
    }
}
