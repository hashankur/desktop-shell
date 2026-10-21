pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

import qs.components
import qs.config
import qs.services
import "./components" as SettingsComponents

// Quick page: the switches and sliders worth reaching in one click.
// Networks and devices have their own pages.
Item {
    id: root

    implicitHeight: 300

    readonly property var btAdapter: Bluetooth.defaultAdapter

    onVisibleChanged: {
        if (visible)
            PowerProfiles.refresh();
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

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 440
            Layout.alignment: Qt.AlignTop
            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                HudLabel {
                    label: "Connectivity"
                }

                Rule {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                SettingsComponents.ToggleTile {
                    Layout.fillWidth: true
                    iconSource: Quickshell.iconPath(WifiStatus.wifiEnabled && WifiStatus.connected ? "network-wireless-symbolic" : "network-wireless-offline-symbolic", true)
                    label: "Wi-Fi"
                    checked: WifiStatus.wifiEnabled
                    onClicked: WifiStatus.toggleWifi()
                }

                SettingsComponents.ToggleTile {
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

                SettingsComponents.ToggleTile {
                    Layout.fillWidth: true
                    iconSource: Notifications.dnd ? Quickshell.iconPath("notifications-disabled-symbolic", true) : Quickshell.iconPath("preferences-system-notifications-symbolic", true)
                    label: "DND"
                    checked: Notifications.dnd
                    onClicked: Notifications.dnd = !Notifications.dnd
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small
                spacing: Appearance.spacing.small
                visible: PowerProfiles.available

                HudLabel {
                    label: "Power profile"
                }

                Rule {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
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
        }

        Rule {
            vertical: true
            Layout.fillHeight: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 440
            Layout.alignment: Qt.AlignTop
            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                HudLabel {
                    label: "Display and sound"
                }

                Rule {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            SettingsComponents.SliderRow {
                Layout.fillWidth: true
                visible: Brightness.available
                iconName: "display-brightness-symbolic"
                value: Brightness.brightness
                valueText: `${Math.round(Brightness.brightness * 100)}%`
                onMoved: function (v) {
                    root._pendingBrightness = v;
                    brightnessDebounce.restart();
                }
            }

            SettingsComponents.SliderRow {
                Layout.fillWidth: true
                visible: Volume.available
                iconName: root.volumeIconName()
                iconClickable: true
                value: Volume.volume
                valueText: Volume.muted ? "mute" : `${Math.round(Volume.volume * 100)}%`
                onMoved: function (v) {
                    Volume.setVolume(v);
                }
                onIconClicked: Volume.toggleMute()
            }

            StyledText {
                Layout.fillWidth: true
                visible: Volume.available && Volume.sinkName.length > 0
                text: Volume.sinkName
                mono: true
                elide: Text.ElideRight
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.xs
            }
        }
    }
}
