import Quickshell
import QtQuick

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

            Item {
                anchors.top: rectanglesRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Clock {
                    anchors.centerIn: parent
                }
            }
        }
    }
}
