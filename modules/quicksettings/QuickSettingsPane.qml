pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

import qs.components
import qs.config
import qs.services
import "./components" as QSComponents

// Quick settings pane for the console band. The window shell (IPC,
// backdrop, focus) lives in modules/console/ConsoleWindow.qml.
Item {
    id: root

    // Height mirrors the old windowed frame: content plus its padding.
    implicitHeight: frameContent.implicitHeight + Appearance.padding.large * 2

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

    ColumnLayout {
        id: frameContent
        anchors {
            fill: parent
            margins: Appearance.padding.large
        }
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            HudLabel {
                label: "QUICK SETTINGS"
            }

            Rule {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small
            visible: WifiStatus.wifiEnabled && root.networkCount > 0

            HudLabel {
                label: "Networks"
            }

            Repeater {
                model: root.wifiNetworks

                delegate: Item {
                    id: netRow
                    required property var modelData

                    // The paper chip shows only when not hovered; every
                    // foreground follows this single inverted state.
                    property bool inverted: netRow.modelData.connected && !netMouse.containsMouse

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
                            color: netRow.inverted ? Appearance.colors.on_primary_container : Appearance.colors.on_surface
                            font.pixelSize: Appearance.fontSize.sm
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Icon {
                            centerVertically: false
                            Layout.alignment: Qt.AlignVCenter
                            visible: netRow.modelData.security !== WifiSecurityType.Open
                            source: Quickshell.iconPath("channel-secure-symbolic", true)
                            tint: netRow.inverted ? Appearance.colors.on_primary_container : Appearance.colors.on_surface
                            tintAmount: netRow.inverted ? 1 : 0.5
                        }

                        StyledText {
                            text: Math.round((netRow.modelData.signalStrength || 0) * 100) + "%"
                            color: netRow.inverted ? Appearance.colors.on_primary_container : Appearance.colors.on_surface_variant
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small
            visible: root.btAdapter !== null && root.btAdapter.enabled && root.bondedDevices.length > 0

            HudLabel {
                label: "Devices"
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
                            centerVertically: false
                            Layout.alignment: Qt.AlignVCenter
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
