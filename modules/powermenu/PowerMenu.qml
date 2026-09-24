pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.components
import qs.config
import qs.services
import "./components" as PowerComponents

PanelWindow {
    id: root

    visible: false
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    aboveWindows: true
    focusable: true
    color: "transparent"

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

    Component.onCompleted: Session.setWindow(root)

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

    IpcHandler {
        target: "powermenu"

        function toggle() {
            Session.toggle();
        }

        function open() {
            Session.open();
        }

        function close() {
            Session.close();
        }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (root.pendingAction !== "") {
                root.cancelAction();
            } else {
                Session.close();
            }
        }

        // Click on transparent background to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: Session.close()
        }

        Rectangle {
            id: frame
            anchors.centerIn: parent
            width: Math.min(560, parent.width - Appearance.spacing.large * 2)
            height: frameContent.implicitHeight + Appearance.spacing.large * 2
            radius: Appearance.rounding.large
            color: Appearance.colors.surface
            border.color: Appearance.colors.surface_bright

            // Prevent clicks inside the frame from closing the menu
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: frameContent
                anchors {
                    fill: parent
                    margins: Appearance.spacing.large
                }
                spacing: Appearance.spacing.large

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
                        label: "Shutdown"
                        onClicked: root.requestAction("shutdown")
                    }

                    PowerComponents.PowerActionButton {
                        Layout.fillWidth: true
                        iconSource: Quickshell.iconPath("system-reboot-symbolic")
                        label: "Restart"
                        onClicked: root.requestAction("restart")
                    }

                    PowerComponents.PowerActionButton {
                        Layout.fillWidth: true
                        iconSource: Quickshell.iconPath("weather-clear-night-symbolic")
                        label: "Suspend"
                        onClicked: root.requestAction("suspend")
                    }

                    PowerComponents.PowerActionButton {
                        Layout.fillWidth: true
                        iconSource: Quickshell.iconPath("system-lock-screen-symbolic")
                        label: "Lock"
                        onClicked: root.requestAction("lock")
                    }

                    PowerComponents.PowerActionButton {
                        Layout.fillWidth: true
                        iconSource: Quickshell.iconPath("system-log-out-symbolic")
                        label: "Logout"
                        onClicked: root.requestAction("logout")
                    }

                    PowerComponents.PowerActionButton {
                        Layout.fillWidth: true
                        iconSource: Quickshell.iconPath("preferences-system-symbolic")
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
    }
}
