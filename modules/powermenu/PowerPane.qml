pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.components
import qs.config
import qs.services
import "./components" as PowerComponents

// Power pane for the console band. The window shell (IPC, backdrop,
// focus, Esc) lives in modules/console/ConsoleWindow.qml.
Item {
    id: root

    implicitHeight: 150

    // Pending destructive action awaiting confirmation ("" = idle).
    property string pendingAction: ""
    readonly property string pendingActionLabel: {
        switch (pendingAction) {
        case "shutdown": return "shut down";
        case "restart": return "restart";
        case "suspend": return "suspend";
        case "firmware": return "reboot into firmware setup";
        default: return pendingAction;
        }
    }

    onVisibleChanged: {
        if (visible)
            root.pendingAction = "";
    }

    function shutdown() {
        Session.close();
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function restart() {
        Session.close();
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function suspend() {
        Session.close();
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function lock() {
        Session.close();
        Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"]);
    }

    function logout() {
        Session.close();
        Quickshell.execDetached(["niri", "msg", "action", "quit"]);
    }

    function firmwareSetup() {
        Session.close();
        Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
    }

    // Destructive / system-state actions ask first; reversible ones
    // (lock, logout) run immediately.
    function requestAction(name) {
        switch (name) {
        case "shutdown":
        case "restart":
        case "suspend":
        case "firmware":
            root.pendingAction = name;
            break;
        case "lock":
            lock();
            break;
        case "logout":
            logout();
            break;
        }
    }

    function confirmAction() {
        const action = root.pendingAction;
        root.pendingAction = "";
        switch (action) {
        case "shutdown": shutdown(); break;
        case "restart": restart(); break;
        case "suspend": suspend(); break;
        case "firmware": firmwareSetup(); break;
        }
    }

    function cancelAction() {
        root.pendingAction = "";
    }

    // One row of cells divided by Rules; the confirmation swaps into the
    // same box, so the band does not change height mid-action.
    Item {
        id: frameContent
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            spacing: 0
            visible: root.pendingAction === ""

            Repeater {
                model: [{
                    action: "shutdown",
                    icon: "system-shutdown-symbolic",
                    label: "Shutdown"
                }, {
                    action: "restart",
                    icon: "system-reboot-symbolic",
                    label: "Restart"
                }, {
                    action: "suspend",
                    icon: "weather-clear-night-symbolic",
                    label: "Suspend"
                }, {
                    action: "lock",
                    icon: "system-lock-screen-symbolic",
                    label: "Lock"
                }, {
                    action: "logout",
                    icon: "system-log-out-symbolic",
                    label: "Logout"
                }, {
                    action: "firmware",
                    icon: "preferences-system-symbolic",
                    label: "Firmware"
                }]

                delegate: RowLayout {
                    id: cell

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Rule {
                        vertical: true
                        visible: cell.index > 0
                        Layout.fillHeight: true
                    }

                    PowerComponents.PowerActionButton {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        iconSource: Quickshell.iconPath(cell.modelData.icon)
                        indexLabel: `0${cell.index + 1}`
                        label: cell.modelData.label
                        onClicked: root.requestAction(cell.modelData.action)
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: root.pendingAction !== ""
            spacing: Appearance.spacing.normal

            StyledText {
                text: "Are you sure you want to " + root.pendingActionLabel + "?"
                font.pixelSize: Appearance.fontSize.lg
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                spacing: Appearance.spacing.normal
                Layout.alignment: Qt.AlignHCenter

                StyledButton {
                    text: "Yes"
                    onClicked: root.confirmAction()
                }

                StyledButton {
                    text: "Cancel"
                    onClicked: root.cancelAction()
                }
            }
        }
    }
}
