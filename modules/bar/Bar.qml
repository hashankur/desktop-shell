import Quickshell
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components
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

                Rule {
                    Layout.fillHeight: true
                    vertical: true
                }

                // Center section
                Item {
                    Layout.fillHeight: true
                    Layout.preferredWidth: centerRow.implicitWidth

                    Row {
                        id: centerRow
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.large

                        Clock {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Separates clock and event chip the way the left and
                        // right sections separate their groups. Hides with the
                        // chip so a day without events leaves no stray tick.
                        Rule {
                            vertical: true
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                            visible: nextEventChip.visible
                        }

                        NextEvent {
                            id: nextEventChip
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rule {
                    Layout.fillHeight: true
                    vertical: true
                }

                // Right section
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 20

                        Mpris {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        SystemTray {
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

                        Rule {
                            vertical: true
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        HudLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "PWR"
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
