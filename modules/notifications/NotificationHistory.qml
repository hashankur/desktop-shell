import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import qs.config
import qs.services

PanelWindow {
    id: historyWindow
    implicitWidth: 450
    implicitHeight: 520
    screen: Quickshell.screens[0]
    anchors.top: true
    anchors.right: true
    margins.top: 16
    margins.right: 16
    margins.bottom: 16
    margins.left: 16
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Appearance.colors.surface_container_lowest
        border.color: Appearance.colors.surface_container

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Notifications"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: Appearance.colors.on_surface
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Clear All"
                    onClicked: {
                        Notifications.clearHistory()
                    }
                }
                Button {
                    text: "Close"
                    onClicked: historyWindow.visible = false
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: Notifications.historyModel
                spacing: 8

                delegate: Rectangle {
                    width: list.width
                    height: 80
                    radius: 8
                    color: Appearance.colors.surface_container

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Image {
                            visible: model.icon && model.icon !== ""
                            source: model.icon
                            width: 48
                            height: 48
                            fillMode: Image.PreserveAspectFit
                            Layout.alignment: Qt.AlignTop
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: model.title
                                color: Appearance.colors.on_surface
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.body
                                color: Appearance.colors.on_surface
                                font.pixelSize: 12
                                opacity: 0.8
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                text: model.app + " · " + Qt.formatDateTime(new Date(model.timestamp), "hh:mm")
                                color: Appearance.colors.on_surface
                                font.pixelSize: 11
                                opacity: 0.6
                                elide: Text.ElideRight
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: 6

                            Button {
                                text: "✓"
                                onClicked: {
                                    // TODO: trigger action
                                }
                            }

                            Button {
                                text: "✕"
                                onClicked: {
                                    Notifications.historyModel.remove(index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_Escape) historyWindow.visible = false
    }
}
