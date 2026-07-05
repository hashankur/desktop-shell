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

    function logout() {
        Session.close();
        Quickshell.execDetached(["niri", "msg", "action", "quit"]);
    }

    IpcHandler {
        target: "powermenu"

        function toggle() {
            Session.toggle();
        }
    }

    Keys.onEscapePressed: Session.close()

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
        radius: 22
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
                columns: 4
                columnSpacing: Appearance.spacing.normal
                rowSpacing: Appearance.spacing.normal
                Layout.alignment: Qt.AlignHCenter

                PowerComponents.PowerActionButton {
                    iconSource: Quickshell.iconPath("system-shutdown-symbolic")
                    label: "Shutdown"
                    iconColor: Appearance.colors.error
                    onClicked: root.shutdown()
                }

                PowerComponents.PowerActionButton {
                    iconSource: Quickshell.iconPath("system-reboot-symbolic")
                    label: "Restart"
                    iconColor: Appearance.colors.error
                    onClicked: root.restart()
                }

                PowerComponents.PowerActionButton {
                    iconSource: Quickshell.iconPath("weather-clear-night-symbolic")
                    label: "Suspend"
                    iconColor: Appearance.colors.primary
                    onClicked: root.suspend()
                }

                PowerComponents.PowerActionButton {
                    iconSource: Quickshell.iconPath("system-log-out-symbolic")
                    label: "Logout"
                    iconColor: Appearance.colors.primary
                    onClicked: root.logout()
                }
            }
        }
    }
}
