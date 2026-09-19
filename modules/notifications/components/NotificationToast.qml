import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import qs.components
import qs.config

Item {
    id: root
    property var notificationData
    property var notificationObject: null
    property int autoHideTimeout: notificationData?.timeout > 0 ? notificationData.timeout : 4000
    property bool autoHideEnabled: true
    property bool _dismissed: false

    signal dismissed

    width: 400
    implicitHeight: 100

    Rectangle {
        id: content
        anchors.fill: parent
        color: Appearance.colors.surface_container_low
        border.width: 2
        border.color: Appearance.colors.surface_container
        radius: 12
        opacity: 0

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 15

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: root.notificationData?.app || "Notification"
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.xs
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: Qt.formatDateTime(new Date(root.notificationData?.timestamp || Date.now()), "MMM d")
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.xs
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
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                StyledText {
                    text: root.notificationData?.title || ""
                    font.weight: Font.Black
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 1
                }

                StyledText {
                    text: root.notificationData?.body || ""
                    color: Appearance.colors.on_surface_variant
                    font.pixelSize: Appearance.fontSize.sm
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    maximumLineCount: 1
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.notificationObject?.actions?.length > 0) {
                    root.notificationObject.actions[0].invoke();
                }
                root.dismiss();
            }
        }
    }

    Timer {
        id: autoHideTimer
        interval: root.autoHideTimeout
        onTriggered: root.dismiss()
    }

    Component.onCompleted: {
        if (root.notificationData) {
            content.opacity = 1.0;
            if (root.autoHideEnabled) {
                autoHideTimer.start();
            }
        }
    }

    function dismiss() {
        if (root._dismissed)
            return;
        root._dismissed = true;
        autoHideTimer.stop();
        content.opacity = 0;
        root.visible = false;
        if (root.notificationObject) {
            try {
                root.notificationObject.dismiss();
            } catch (e) {
            }
        }
        // The creator owns destruction; it reacts to `dismissed`.
        Qt.callLater(() => root.dismissed());
    }
}
