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

    // Content keeps its old windowed width cap so the tiles do not
    // stretch across the full band.
    readonly property int contentWidth: Math.min(560, width - Appearance.spacing.large * 2)

    implicitHeight: frameContent.implicitHeight + Appearance.spacing.large * 2

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

    ColumnLayout {
        id: frameContent
        width: root.contentWidth
        x: (root.width - width) / 2
        anchors.top: parent.top
        anchors.topMargin: Appearance.spacing.large
        spacing: Appearance.spacing.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            HudLabel {
                label: "POWER // SESSION"
            }

            Rule {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        GridLayout {
            columns: 3
            columnSpacing: Appearance.spacing.normal
            rowSpacing: Appearance.spacing.normal
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            visible: root.pendingAction === ""

            PowerComponents.PowerActionButton {
                Layout.fillWidth: true
                iconSource: Quickshell.iconPath("system-shutdown-symbolic")
                indexLabel: "01"
                label: "Shutdown"
                onClicked: root.requestAction("shutdown")
            }

            PowerComponents.PowerActionButton {
                Layout.fillWidth: true
                iconSource: Quickshell.iconPath("system-reboot-symbolic")
                indexLabel: "02"
                label: "Restart"
                onClicked: root.requestAction("restart")
            }

            PowerComponents.PowerActionButton {
                Layout.fillWidth: true
                iconSource: Quickshell.iconPath("weather-clear-night-symbolic")
                indexLabel: "03"
                label: "Suspend"
                onClicked: root.requestAction("suspend")
            }

            PowerComponents.PowerActionButton {
                Layout.fillWidth: true
                iconSource: Quickshell.iconPath("system-lock-screen-symbolic")
                indexLabel: "04"
                label: "Lock"
                onClicked: root.requestAction("lock")
            }

            PowerComponents.PowerActionButton {
                Layout.fillWidth: true
                iconSource: Quickshell.iconPath("system-log-out-symbolic")
                indexLabel: "05"
                label: "Logout"
                onClicked: root.requestAction("logout")
            }

            PowerComponents.PowerActionButton {
                Layout.fillWidth: true
                iconSource: Quickshell.iconPath("preferences-system-symbolic")
                indexLabel: "06"
                label: "Firmware"
                onClicked: root.requestAction("firmware")
            }
        }

        // Confirmation state for destructive actions
        ColumnLayout {
            visible: root.pendingAction !== ""
            spacing: Appearance.spacing.normal
            Layout.alignment: Qt.AlignHCenter

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
