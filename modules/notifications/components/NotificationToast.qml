import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs.components
import qs.config

Item {
    id: root
    property var notificationData
    property var notificationObject: null
    property int autoHideTimeout: notificationData?.timeout > 0 ? notificationData.timeout : 4000
    property bool autoHideEnabled: true
    // History rows in the dashboard allow a second body line; live toasts stay single-line.
    property bool allowMultilineBody: false
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

        // First child = bottom of the stack: receives body clicks (layout
        // items above don't accept mouse events) but never covers the close
        // button, which sits higher and takes precedence.
        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                if (root.notificationObject) {
                    if (root.notificationObject.actions?.length > 0) {
                        root.notificationObject.actions[0].invoke();
                    }
                    root.dismiss();
                } else if (mouse.button === Qt.MiddleButton) {
                    // History rows: middle-click removes, plain click does nothing.
                    root.dismiss();
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 15

            ClippingRectangle {
                id: iconArea
                readonly property string imageSource: root.notificationData?.image ?? ""
                readonly property string iconName: root.notificationData?.icon ?? ""
                readonly property string resolvedImage: imageSource !== "" ? (imageSource.indexOf("://") >= 0 ? imageSource : "file://" + imageSource) : ""
                readonly property bool showImage: imageSource !== "" && !imageLoadFailed
                readonly property bool showIcon: !showImage && iconName !== ""

                property bool imageLoadFailed: false

                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignVCenter
                visible: showImage || showIcon
                radius: Appearance.rounding.full
                color: "transparent"

                Image {
                    anchors.fill: parent
                    source: iconArea.resolvedImage
                    visible: iconArea.showImage
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Image.Error) {
                            iconArea.imageLoadFailed = true;
                        }
                    }
                }

                IconImage {
                    anchors.fill: parent
                    source: iconArea.iconName !== "" ? Quickshell.iconPath(iconArea.iconName, true) : ""
                    visible: iconArea.showIcon
                    smooth: true
                }
            }

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
                        text: Qt.formatDateTime(new Date(root.notificationData?.timestamp || Date.now()), "MMM d · h:mm AP")
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.xs
                        Layout.alignment: Qt.AlignRight
                    }

                    StyledButton {
                        ghost: true
                        text: "×"
                        padding: Appearance.padding.smaller
                        verticalPadding: Appearance.padding.smaller
                        contentItem: StyledText {
                            text: "×"
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: Appearance.fontSize.sm
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.dismiss()
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
                    maximumLineCount: root.allowMultilineBody ? 2 : 1
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.standard
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
                console.warn("Failed to dismiss notification:", e);
            }
        }
        // The creator owns destruction; it reacts to `dismissed`.
        Qt.callLater(() => root.dismissed());
    }
}
