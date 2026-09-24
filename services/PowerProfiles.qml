pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property string profile: ""

    function refresh() {
        getProc.exec(["powerprofilesctl", "get"]);
    }

    function setProfile(name) {
        if (!root.available)
            return;
        root.profile = name;
        Quickshell.execDetached(["powerprofilesctl", "set", name]);
    }

    property string _pendingProfile: ""

    Process {
        id: getProc

        stdout: StdioCollector {
            onStreamFinished: root._pendingProfile = this.text.trim()
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0 && root._pendingProfile !== "") {
                root.available = true;
                root.profile = root._pendingProfile;
            } else {
                root.available = false;
            }
            root._pendingProfile = "";
        }
    }

    Component.onCompleted: refresh()
}
