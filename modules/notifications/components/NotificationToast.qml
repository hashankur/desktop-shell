import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import qs.config
import qs.services

Item {
    id: root
    property var notificationData: ({})
    property var notificationObject: null

    width: 400
    implicitHeight: 100

    Rectangle {
        id: content
        anchors.fill: parent
        color: Appearance.colors.surface_container_lowest
        border {
            width: 2
            color: Appearance.colors.surface_container
        }
        radius: 12

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // Album art / Icon on left
            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                radius: 12
                color: Appearance.colors.surface_container_low
                clip: true

                Image {
                    anchors.fill: parent
                    source: notificationData.icon || ""
                    fillMode: Image.PreserveAspectCrop
                    visible: notificationData.icon && notificationData.icon !== ""
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !parent.Image
                    color: Appearance.colors.primary
                }
            }

            // Text content on right
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 5
                spacing: 4

                // Header row with app name and close button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: notificationData.app || "Notification"
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Qt.formatDateTime(new Date(notificationData.timestamp || Date.now()), "MMM d")
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignRight
                    }

                    Button {
                        text: "×"
                        onClicked: root.dismiss()
                        background: Rectangle {
                            color: "transparent"
                        }
                        contentItem: Text {
                            text: "×"
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                    }
                }

                // Title
                Text {
                    text: notificationData.title || ""
                    color: Appearance.colors.on_surface
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 1
                }

                // Body / Subtitle
                Text {
                    text: notificationData.body || ""
                    color: Appearance.colors.on_surface_variant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 1
                    Layout.fillHeight: true
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Timer {
            id: hideTimer
            interval: Math.max(0, notificationData.timeout > 0 ? notificationData.timeout : 4000)
            running: false
            repeat: false
            onTriggered: root.dismiss()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.notificationObject && root.notificationObject.actions && root.notificationObject.actions.length > 0) {
                    root.notificationObject.actions[0].invoke();
                }
                root.dismiss();
            }
        }

        Component.onCompleted: {
            content.opacity = 1.0;
            hideTimer.start();
        }
    }

    function dismiss() {
        content.opacity = 0;
        hideTimer.stop();
        if (root.notificationObject) {
            root.notificationObject.dismiss();
        }
        Qt.callLater(function () {
            root.destroy();
        });
    }
}
