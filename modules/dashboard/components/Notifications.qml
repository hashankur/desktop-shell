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

    implicitWidth: 470
    implicitHeight: 520

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: "Notifications"
                    font.pixelSize: Appearance.fontSize.lg
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: "Clear all"
                    onClicked: Notifications.clearHistory()
                }
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Appearance.spacing.small
                model: Notifications.historyModel

                delegate: Item {
                    required property var model
                    width: listView.width
                    implicitHeight: 100

                    NotificationToast {
                        anchors.fill: parent
                        notificationData: parent.model
                        autoHideEnabled: false
                    }
                }
            }
        }
    }
}
