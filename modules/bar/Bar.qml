import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components
import qs.modules.bar.components

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 44

            color: Appearance.colors.surface_container_lowest

            Workspaces {
                id: rectanglesRow
            }

            RowLayout {
                anchors.top: rectanglesRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                spacing: 10

                // Left section
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 20

                        SystemStats {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        FocusedWindow {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Center section
                Item {
                    Layout.fillHeight: true
                    Layout.preferredWidth: implicitWidth

                    Clock {
                        anchors.centerIn: parent
                    }
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

                        Wifi {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Battery {}

                        NotificationsHistory {}
                    }
                }
            }
        }
    }
}
