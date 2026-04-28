import Quickshell
import QtQuick
import QtQuick.Layouts

import qs.config

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

                    FocusedWindow {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
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

                    Mpris {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
