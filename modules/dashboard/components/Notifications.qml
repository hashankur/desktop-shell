pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services
import "../../notifications/components"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                text: "Notifications"
                font.pixelSize: Appearance.fontSize.lg
            }

            StyledText {
                visible: Notifications.historyModel.count > 0
                text: `(${Notifications.historyModel.count})`
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.sm
            }

            Rectangle {
                visible: Notifications.dnd
                radius: Appearance.rounding.full
                color: Appearance.colors.primary_container
                implicitHeight: 22
                implicitWidth: dndLabel.implicitWidth + Appearance.padding.small * 2

                StyledText {
                    id: dndLabel
                    anchors.centerIn: parent
                    text: "DND"
                    color: Appearance.colors.on_primary_container
                    font.pixelSize: Appearance.fontSize.xs
                    font.weight: Font.DemiBold
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledButton {
                visible: Notifications.historyModel.count > 0
                text: "Clear all"
                onClicked: Notifications.clearHistory()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: Appearance.spacing.small
                model: Notifications.historyModel
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    id: delegateRoot

                    required property var model
                    required property int index

                    width: listView.width
                    implicitHeight: 100

                    NotificationToast {
                        anchors.fill: parent
                        notificationData: delegateRoot.model
                        autoHideEnabled: false
                        allowMultilineBody: true
                        onDismissed: Notifications.removeHistory(delegateRoot.index)
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: Notifications.historyModel.count === 0
                text: "No notifications yet"
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.sm
            }
        }
    }
}
