import Quickshell
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland

import qs.config
import qs.components
import qs.services
import qs.modules.bar.components

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 44

            color: Appearance.colors.surface

            IdleInhibitor {
                window: barWindow
                enabled: IdleInhibit.enabled
            }

            Workspaces {
                id: rectanglesRow
                outputName: barWindow.modelData.name
            }

            RowLayout {
                anchors.top: rectanglesRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 1
                spacing: 10

                // Left section
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 20

                        HudLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "SYS"
                        }

                        SystemStats {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rule {
                            vertical: true
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        FocusedWindow {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Center section: the clock stays pinned to the middle of the
                // bar and chips hang off both sides of it, each behind a short
                // tick like the other groups'. The section reserves the wider
                // side on both, which keeps the clock still; the right section
                // reclaims the unused room (see maxWidth below).
                Item {
                    id: centerSection
                    Layout.fillHeight: true

                    readonly property real gap: Appearance.spacing.large
                    readonly property real extentLeft: nextEventChip.visible ? nextEventChip.implicitWidth + 2 * gap + 1 : 0
                    readonly property real extentRight: notifChip.visible ? notifChip.implicitWidth + 2 * gap + 1 : 0
                    readonly property real reserve: Math.max(extentLeft, extentRight)
                    Layout.preferredWidth: clock.implicitWidth + 2 * reserve

                    Clock {
                        id: clock
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rule {
                        id: eventRule
                        vertical: true
                        height: clock.height
                        anchors.right: clock.left
                        anchors.rightMargin: centerSection.gap
                        anchors.verticalCenter: parent.verticalCenter
                        visible: nextEventChip.visible
                    }

                    NextEvent {
                        id: nextEventChip
                        anchors.right: eventRule.left
                        anchors.rightMargin: centerSection.gap
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rule {
                        id: notifRule
                        vertical: true
                        height: clock.height
                        anchors.left: clock.right
                        anchors.leftMargin: centerSection.gap
                        anchors.verticalCenter: parent.verticalCenter
                        visible: notifChip.visible
                    }

                    NotifCount {
                        id: notifChip
                        anchors.left: notifRule.right
                        anchors.leftMargin: centerSection.gap
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Right section
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Mpris {
                        id: mediaChip
                        anchors.right: rightRow.left
                        anchors.rightMargin: rightRow.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        // Whatever the other widgets leave, minus a gap so the center block
                        // stays visually isolated; the title elides into it.
                        maxWidth: parent.width - rightRow.width - rightRow.spacing - Appearance.spacing.large + (centerSection.reserve - centerSection.extentRight)
                    }

                    Row {
                        id: rightRow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 20

                        // Both neighbours come and go (Spotify closed, tray
                        // empty or on another output); the rule after the tray
                        // already divides when the tray stands alone.
                        Rule {
                            vertical: true
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                            visible: mediaChip.visible && trayChip.visible
                        }

                        SystemTray {
                            id: trayChip
                            anchors.verticalCenter: parent.verticalCenter
                            parentWindow: barWindow
                            // Tray lives on the primary output only.
                            activeOnScreen: barWindow.modelData.name === (Quickshell.screens[0]?.name ?? "")
                        }

                        Rule {
                            vertical: true
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        HudLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "NET"
                        }

                        Wifi {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Tether {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rule {
                            vertical: true
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        HudLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "PWR"
                        }

                        Awake {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Battery {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        PowerButton {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Seats the bar as a HUD strip against the desktop.
            Rule {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }
        }
    }
}
