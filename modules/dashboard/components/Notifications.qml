pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

Item {
    id: root

    implicitWidth: 470
    implicitHeight: 520

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.surface_container_lowest

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
                spacing: Appearance.spacing.normal
                model: Notifications.historyModel

                delegate: Rectangle {
                    id: notificationCard
                    required property var model
                    readonly property var entryData: model
                    readonly property string entryApp: entryData.app || "Notification"
                    readonly property string entryTime: Qt.formatDateTime(new Date(entryData.timestamp), "MMM d · hh:mm")
                    readonly property string entryTitle: entryData.title || ""
                    readonly property string entryBody: entryData.body || ""
                    readonly property string entryIconSource: entryData.icon && entryData.icon !== "" ? entryData.icon.toString() : ""
                    readonly property bool entryHasIcon: entryIconSource !== ""

                    width: listView.width
                    height: 96
                    radius: Appearance.rounding.small
                    color: Appearance.colors.surface_container
                    border.color: Appearance.colors.surface_container_high
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            radius: Appearance.rounding.small
                            color: Appearance.colors.surface_container_highest
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 8
                                visible: notificationCard.entryHasIcon
                                source: notificationCard.entryIconSource
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    text: notificationCard.entryApp
                                    color: Appearance.colors.on_surface_variant
                                    font.pixelSize: Appearance.fontSize.xs
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: notificationCard.entryTime
                                    color: Appearance.colors.on_surface_variant
                                    font.pixelSize: Appearance.fontSize.xs
                                }
                            }

                            StyledText {
                                text: notificationCard.entryTitle
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: notificationCard.entryBody
                                color: Appearance.colors.on_surface_variant
                                font.pixelSize: Appearance.fontSize.sm
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
