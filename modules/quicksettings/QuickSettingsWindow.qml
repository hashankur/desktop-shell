pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking

import qs.components
import qs.config
import qs.services
import "./components" as QSComponents

OverlayWindow {
    id: root

    signal closeRequested

    // Content slides down from above on enter, back up on exit.
    enterOffsetY: -40
    color: "transparent"
    exclusiveZone: 0
    focusable: true
    aboveWindows: true
    screen: Niri.focusedScreen

    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    IpcHandler {
        target: "quicksettings"

        function toggle() {
            QuickSettings.toggle();
        }
        function open() {
            QuickSettings.open();
        }
        function close() {
            QuickSettings.close();
        }
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property int networkCount: WifiStatus.wifiDevice ? WifiStatus.wifiDevice.networks.values.length : 0
    readonly property var wifiNetworks: {
        const device = WifiStatus.wifiDevice;
        if (!device)
            return [];
        return (device.networks.values || []).slice().sort((a, b) => (b.signalStrength || 0) - (a.signalStrength || 0));
    }
    readonly property var bondedDevices: {
        const adapter = btAdapter;
        if (!adapter)
            return [];
        return (adapter.devices.values || []).filter(d => d && (d.bonded || d.paired));
    }

    onVisibleChanged: {
        if (visible) {
            PowerProfiles.refresh();
            // Kick a fresh scan so the list isn't stale.
            if (WifiStatus.wifiEnabled && WifiStatus.wifiDevice)
                WifiStatus.wifiDevice.scannerEnabled = true;
        }
    }

    function connectNetwork(net) {
        if (!net || net.connected)
            return;
        const isOpen = net.security === WifiSecurityType.Open;
        if (!net.known && !isOpen) {
            Quickshell.execDetached(["notify-send", "-a", "Shell", "-u", "normal", "Quick Settings", "Password required for \u201C" + net.name + "\u201D — set it up once in your network settings"]);
            return;
        }
        net.connect();
    }

    function volumeIconName() {
        if (Volume.muted || Volume.volume === 0)
            return "audio-volume-muted-symbolic";
        if (Volume.volume < 0.34)
            return "audio-volume-low-symbolic";
        if (Volume.volume < 0.67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    // Trailing debounce: brightnessctl spawns a process per write.
    property real _pendingBrightness: 0
    Timer {
        id: brightnessDebounce
        interval: 80
        onTriggered: Brightness.setBrightness(root._pendingBrightness)
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onReleased: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            }
        }

        // Click on transparent background to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }

        Rectangle {
        id: frame
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12
        width: 360
        height: frameContent.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.large
        color: Appearance.colors.surface
        border.color: Appearance.colors.surface_bright
        border.width: 1
        opacity: root.animOpacity
        transform: Translate {
            y: root.animY
        }

        // Prevent clicks inside the frame from closing the panel
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: frameContent
            anchors {
                fill: parent
                margins: Appearance.padding.large
            }
            spacing: Appearance.spacing.normal

            // ── Toggles ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                QSComponents.ToggleTile {
                    Layout.fillWidth: true
                    iconSource: Quickshell.iconPath(WifiStatus.wifiEnabled && WifiStatus.connected ? "network-wireless-symbolic" : "network-wireless-offline-symbolic", true)
                    label: "Wi-Fi"
                    checked: WifiStatus.wifiEnabled
                    onClicked: WifiStatus.toggleWifi()
                }

                QSComponents.ToggleTile {
                    Layout.fillWidth: true
                    visible: root.btAdapter !== null
                    iconSource: Quickshell.iconPath("bluetooth-symbolic", true)
                    label: "Bluetooth"
                    checked: root.btAdapter !== null && root.btAdapter.enabled
                    onClicked: {
                        if (root.btAdapter)
                            root.btAdapter.enabled = !root.btAdapter.enabled;
                    }
                }

                QSComponents.ToggleTile {
                    Layout.fillWidth: true
                    iconSource: Notifications.dnd ? Quickshell.iconPath("notifications-disabled-symbolic", true) : Quickshell.iconPath("preferences-system-notifications-symbolic", true)
                    label: "DND"
                    checked: Notifications.dnd
                    onClicked: Notifications.dnd = !Notifications.dnd
                }
            }

            // ── Power profiles ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small
                visible: PowerProfiles.available

                StyledButton {
                    Layout.fillWidth: true
                    text: "Saver"
                    checked: PowerProfiles.profile === "power-saver"
                    onClicked: PowerProfiles.setProfile("power-saver")
                }
                StyledButton {
                    Layout.fillWidth: true
                    text: "Balanced"
                    checked: PowerProfiles.profile === "balanced"
                    onClicked: PowerProfiles.setProfile("balanced")
                }
                StyledButton {
                    Layout.fillWidth: true
                    text: "Performance"
                    checked: PowerProfiles.profile === "performance"
                    onClicked: PowerProfiles.setProfile("performance")
                }
            }

            // ── Brightness ───────────────────────────────────────
            QSComponents.SliderRow {
                Layout.fillWidth: true
                visible: Brightness.available
                iconName: "display-brightness-symbolic"
                value: Brightness.brightness
                onMoved: function (v) {
                    root._pendingBrightness = v;
                    brightnessDebounce.restart();
                }
            }

            // ── Volume ───────────────────────────────────────────
            QSComponents.SliderRow {
                Layout.fillWidth: true
                visible: Volume.available
                iconName: root.volumeIconName()
                iconClickable: true
                value: Volume.volume
                onMoved: function (v) {
                    Volume.setVolume(v);
                }
                onIconClicked: Volume.toggleMute()
            }

            // ── Networks ─────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small
                visible: WifiStatus.wifiEnabled && root.networkCount > 0

                StyledText {
                    text: "Networks"
                    font.pixelSize: Appearance.fontSize.xs
                    color: Appearance.colors.on_surface_variant
                }

                Repeater {
                    model: root.wifiNetworks

                    delegate: Item {
                        id: netRow
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: netMouse.containsMouse ? Appearance.colors.surface_container_high : (netRow.modelData.connected ? Appearance.colors.primary_container : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.durations.small
                                    easing.bezierCurve: Appearance.anim.curves.standard
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Appearance.padding.smaller
                            anchors.rightMargin: Appearance.padding.smaller
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: netRow.modelData.name || ""
                                color: netRow.modelData.connected ? Appearance.colors.primary : Appearance.colors.on_surface
                                font.pixelSize: Appearance.fontSize.sm
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Icon {
                                visible: netRow.modelData.security !== WifiSecurityType.Open
                                source: Quickshell.iconPath("channel-secure-symbolic", true)
                            }

                            StyledText {
                                text: Math.round((netRow.modelData.signalStrength || 0) * 100) + "%"
                                color: Appearance.colors.on_surface_variant
                                font.pixelSize: Appearance.fontSize.xs
                            }
                        }

                        MouseArea {
                            id: netMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.connectNetwork(netRow.modelData)
                        }
                    }
                }
            }

            // ── Bluetooth devices ────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small
                visible: root.btAdapter !== null && root.btAdapter.enabled && root.bondedDevices.length > 0

                StyledText {
                    text: "Devices"
                    font.pixelSize: Appearance.fontSize.xs
                    color: Appearance.colors.on_surface_variant
                }

                Repeater {
                    model: root.bondedDevices

                    delegate: Item {
                        id: btRow
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: btMouse.containsMouse ? Appearance.colors.surface_container_high : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.durations.small
                                    easing.bezierCurve: Appearance.anim.curves.standard
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Appearance.padding.smaller
                            anchors.rightMargin: Appearance.padding.smaller
                            spacing: Appearance.spacing.small

                            Icon {
                                source: Quickshell.iconPath("bluetooth-symbolic", true)
                            }

                            StyledText {
                                text: btRow.modelData.name || btRow.modelData.deviceName || ""
                                color: btRow.modelData.connected ? Appearance.colors.on_surface : Appearance.colors.on_surface_variant
                                font.pixelSize: Appearance.fontSize.sm
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                visible: btRow.modelData.batteryAvailable
                                text: btRow.modelData.batteryAvailable ? Math.round(btRow.modelData.battery * 100) + "%" : ""
                                color: Appearance.colors.on_surface_variant
                                font.pixelSize: Appearance.fontSize.xs
                            }

                            StyledText {
                                text: {
                                    if (btRow.modelData.pairing)
                                        return "Pairing…";
                                    if (btRow.modelData.connected)
                                        return "Connected";
                                    return "";
                                }
                                color: btRow.modelData.connected ? Appearance.colors.primary : Appearance.colors.on_surface_variant
                                font.pixelSize: Appearance.fontSize.xs
                            }
                        }

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (btRow.modelData.connected)
                                    btRow.modelData.disconnect();
                                else
                                    btRow.modelData.connect();
                            }
                        }
                    }
                }
            }
        }
    }
    }

    Component.onCompleted: QuickSettings.setWindow(root)
}
