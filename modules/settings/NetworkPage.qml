pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

import qs.components
import qs.config
import qs.services

// Wi-Fi: switch, scan and the network list. Secured networks the machine has
// never joined ask for the password inline instead of sending the user to
// another tool. Everything goes through Quickshell.Networking (never nmcli).
Item {
    id: root

    implicitHeight: 400

    readonly property var wifiNetworks: {
        const device = WifiStatus.wifiDevice;
        if (!device)
            return [];
        return (device.networks.values || []).slice().sort((a, b) => (b.signalStrength || 0) - (a.signalStrength || 0));
    }

    onVisibleChanged: {
        // Kick a fresh scan so the list is not stale.
        if (visible && WifiStatus.wifiEnabled && WifiStatus.wifiDevice)
            WifiStatus.wifiDevice.scannerEnabled = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledButton {
                text: "Wi-Fi"
                checkable: true
                checked: WifiStatus.wifiEnabled
                onClicked: WifiStatus.toggleWifi()
            }

            StyledButton {
                text: "Rescan"
                enabled: WifiStatus.wifiEnabled && WifiStatus.wifiDevice !== null
                onClicked: {
                    // Toggle so a scanner that is already on restarts.
                    WifiStatus.wifiDevice.scannerEnabled = false;
                    WifiStatus.wifiDevice.scannerEnabled = true;
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: (WifiStatus.connected ? `Connected to ${WifiStatus.ssid} (${WifiStatus.signal}%)` : (WifiStatus.wifiEnabled ? "Not connected" : "Wi-Fi is off")) + (WiredStatus.connected ? ` · ${WiredStatus.label}` : "")
                mono: true
                elide: Text.ElideRight
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.sm
            }

            HudLabel {
                visible: WifiStatus.wifiEnabled
                label: `${root.wifiNetworks.length} networks`
            }
        }

        Rule {
            Layout.fillWidth: true
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: list.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: list
                width: parent.width
                spacing: 2

                Repeater {
                    model: WifiStatus.wifiEnabled ? root.wifiNetworks : []

                    delegate: ColumnLayout {
                        id: row

                        required property var modelData

                        readonly property bool secured: row.modelData.security !== WifiSecurityType.Open
                        property bool askPassword: false
                        property string error: ""

                        // The paper chip shows only when not hovered; every
                        // foreground follows this single inverted state.
                        readonly property bool inverted: row.modelData.connected && !rowMouse.containsMouse

                        function activate() {
                            const net = row.modelData;
                            if (net.connected)
                                return;
                            row.error = "";
                            if (net.known || !row.secured)
                                net.connect();
                            else
                                row.askPassword = !row.askPassword;
                        }

                        function submit() {
                            if (pass.text.length === 0)
                                return;
                            row.error = "";
                            row.modelData.connectWithPsk(pass.text);
                            pass.text = "";
                            row.askPassword = false;
                        }

                        Layout.fillWidth: true
                        spacing: 0

                        Connections {
                            target: row.modelData

                            function onConnectionFailed(reason) {
                                row.error = `Could not connect (${reason})`;
                                if (row.secured)
                                    row.askPassword = true;
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 38

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: rowMouse.containsMouse ? Appearance.colors.surface_container_high : (row.modelData.connected ? Appearance.colors.primary_container : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.durations.small
                                        easing.bezierCurve: Appearance.anim.curves.standard
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Appearance.padding.normal
                                anchors.rightMargin: Appearance.padding.normal
                                spacing: Appearance.spacing.normal

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.name || ""
                                    elide: Text.ElideRight
                                    color: row.inverted ? Appearance.colors.on_primary_container : Appearance.colors.on_surface
                                }

                                StyledText {
                                    visible: row.modelData.known && !row.modelData.connected
                                    text: "saved"
                                    mono: true
                                    color: Appearance.colors.on_surface_variant
                                    font.pixelSize: Appearance.fontSize.xs
                                }

                                Icon {
                                    centerVertically: false
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: row.secured
                                    source: Quickshell.iconPath("channel-secure-symbolic", true)
                                    tint: row.inverted ? Appearance.colors.on_primary_container : Appearance.colors.on_surface
                                    tintAmount: row.inverted ? 1 : 0.5
                                }

                                SegmentBar {
                                    Layout.preferredWidth: 60
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitHeight: 8
                                    segments: 5
                                    progress: row.modelData.signalStrength || 0
                                    barColor: row.inverted ? Appearance.colors.on_primary_container : Appearance.colors.primary
                                    trackColor: row.inverted ? Qt.alpha(Appearance.colors.on_primary_container, 0.25) : Appearance.colors.surface_container_high
                                }

                                StyledText {
                                    Layout.preferredWidth: 36
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round((row.modelData.signalStrength || 0) * 100) + "%"
                                    mono: true
                                    color: row.inverted ? Appearance.colors.on_primary_container : Appearance.colors.on_surface_variant
                                    font.pixelSize: Appearance.fontSize.xs
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: row.activate()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: Appearance.padding.small
                            visible: row.askPassword
                            spacing: Appearance.spacing.small

                            TextField {
                                id: pass
                                Layout.fillWidth: true
                                // focus (not forceActiveFocus) hands the field the
                                // window's focus scope; Esc cancels the edit before
                                // it can reach the window's close handler.
                                focus: row.askPassword
                                echoMode: TextInput.Password
                                placeholderText: "Password"
                                color: Appearance.colors.on_surface
                                placeholderTextColor: Appearance.colors.on_surface_variant
                                selectionColor: Appearance.colors.primary
                                font.family: Appearance.font.sans
                                font.pixelSize: Appearance.fontSize.base
                                leftPadding: Appearance.padding.normal
                                background: Rectangle {
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.surface_container
                                    border.width: 1
                                    border.color: pass.activeFocus ? Appearance.colors.primary : Appearance.colors.outline_variant
                                }
                                onAccepted: row.submit()
                                Keys.onEscapePressed: event => {
                                    pass.text = "";
                                    row.askPassword = false;
                                    event.accepted = true;
                                }
                            }

                            StyledButton {
                                text: "Connect"
                                enabled: pass.text.length > 0
                                onClicked: row.submit()
                            }
                        }

                        StyledText {
                            Layout.leftMargin: Appearance.padding.normal
                            visible: row.error.length > 0
                            text: row.error
                            color: Appearance.colors.error
                            font.pixelSize: Appearance.fontSize.xs
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: Appearance.padding.small
                            visible: row.modelData.connected
                            spacing: Appearance.spacing.small

                            StyledButton {
                                text: "Disconnect"
                                onClicked: row.modelData.disconnect()
                            }

                            StyledButton {
                                text: "Forget"
                                onClicked: row.modelData.forget()
                            }
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Appearance.spacing.large
                    visible: WifiStatus.wifiEnabled && root.wifiNetworks.length === 0
                    text: "No networks found"
                    color: Appearance.colors.on_surface_variant
                    font.pixelSize: Appearance.fontSize.sm
                }
            }
        }
    }
}
