pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services
import "Format.js" as Fmt

Item {
    id: root

    // The Status tab is the only consumer of SystemInfo; polling follows
    // visibility so `top` never runs while another tab is showing.
    property bool active: false
    onActiveChanged: SystemInfo.active = root.active
    Component.onDestruction: SystemInfo.active = false

    readonly property string batteryDetail: {
        if (!Battery.available)
            return "";
        if (Battery.isCharging)
            return Battery.timeToFull > 0 ? `Charging, ${Fmt.duration(Battery.timeToFull)} to full` : "Charging";
        if (Battery.isPluggedIn)
            return "Plugged in";
        return Battery.timeToEmpty > 0 ? `${Fmt.duration(Battery.timeToEmpty)} left` : "On battery";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 108
            spacing: Appearance.spacing.normal

            StatTile {
                visible: Battery.available
                divider: false
                title: "Battery"
                value: `${Math.round(Battery.percentage * 100)}%`
                progress: Battery.percentage
                barColor: Battery.isLowAndNotCharging ? Appearance.colors.error : Appearance.colors.primary
                detail: root.batteryDetail
                extra: PowerProfiles.available ? `Profile ${PowerProfiles.profile}` : ""
            }

            StatTile {
                divider: Battery.available
                title: "Network"
                value: WifiStatus.connected ? (WifiStatus.ssid || "Connected") : "Offline"
                progress: WifiStatus.connected ? WifiStatus.signal / 100 : -1
                detail: WifiStatus.connected ? `${WifiStatus.signal}% signal` : ""
                extra: `↓ ${Fmt.rate(SystemInfo.netDown)} ↑ ${Fmt.rate(SystemInfo.netUp)}`
            }

            StatTile {
                title: "Audio"
                value: !Volume.available ? "No sink" : (Volume.muted ? "Muted" : `${Math.round(Volume.volume * 100)}%`)
                progress: Volume.available ? Volume.volume : -1
                barColor: Volume.muted ? Appearance.colors.on_surface_variant : Appearance.colors.primary
            }

            StatTile {
                visible: Brightness.available
                title: "Display"
                value: `${Math.round(Brightness.brightness * 100)}%`
                progress: Brightness.brightness
            }

            StatTile {
                title: "Uptime"
                value: Fmt.duration(SystemInfo.uptimeSeconds)
                detail: "since boot"
            }
        }

        Rule {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.normal

            UsageGraph {
                label: "CPU"
                value: SystemStats.cpuUsage
                history: SystemStats.cpuHistory
                lineColor: Appearance.colors.primary
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 200
            }

            UsageGraph {
                label: "GPU"
                value: SystemStats.gpuUsage
                history: SystemStats.gpuHistory
                available: SystemStats.gpuAvailable
                lineColor: Appearance.colors.secondary
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 200
            }

            UsageGraph {
                label: "Memory"
                value: SystemStats.memoryUsage
                history: SystemStats.memoryHistory
                lineColor: Appearance.colors.tertiary
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 200
            }

            UsageGraph {
                label: "Temp"
                value: SystemStats.temperature
                history: SystemStats.temperatureHistory
                available: SystemStats.temperatureAvailable
                detail: `${SystemStats.temperatureCelsius.toFixed(0)}°C`
                lineColor: Appearance.colors.error
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 200
            }
        }

        Rule {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            spacing: Appearance.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 600
                spacing: Appearance.spacing.small

                HudLabel {
                    label: "Top processes"
                }

                Repeater {
                    model: SystemInfo.topProcesses

                    delegate: RowLayout {
                        id: proc

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        StyledText {
                            Layout.fillWidth: true
                            text: proc.modelData.name
                            mono: true
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.fontSize.sm
                        }

                        StyledText {
                            text: `${proc.modelData.cpu.toFixed(1)}% cpu`
                            mono: true
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: Appearance.fontSize.sm
                        }

                        StyledText {
                            Layout.preferredWidth: 80
                            horizontalAlignment: Text.AlignRight
                            text: `${proc.modelData.mem.toFixed(1)}% mem`
                            mono: true
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: Appearance.fontSize.sm
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            StatTile {
                Layout.preferredWidth: 300
                title: "Storage /"
                value: `${Math.round(SystemInfo.diskUsage * 100)}%`
                progress: SystemInfo.diskUsage
                detail: `${Fmt.bytes(SystemInfo.diskUsed)} of ${Fmt.bytes(SystemInfo.diskTotal)}`
            }
        }
    }
}
