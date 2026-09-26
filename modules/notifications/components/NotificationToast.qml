import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

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
    // Enter/exit state: `_shown` drives the fade (and, for live toasts,
    // the horizontal slide) so both happen before destruction.
    property bool _shown: false
    property bool slideIn: false
    // Critical rows/toasts get a dark red (error_container) background
    // instead of the default surface. History rows read this from the
    // persisted model; entries saved before urgency existed fall back to
    // Normal.
    readonly property bool critical: (root.notificationData?.urgency ?? NotificationUrgency.Normal) === NotificationUrgency.Critical

    signal dismissed

    width: 400
    implicitHeight: 100

    Rectangle {
        id: content
        anchors.fill: parent
        color: root.critical ? Appearance.colors.error_container : Appearance.colors.surface_container_low
        border.width: root.critical ? 0 : 2
        border.color: Appearance.colors.surface_container
        radius: 12
        opacity: root._shown ? 1 : 0
        transform: Translate {
            x: root._shown ? 0 : (root.slideIn ? 40 : 0)

            Behavior on x {
                NumberAnimation {
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }
        }

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
            anchors.margins: Appearance.padding.normal
            spacing: Appearance.spacing.larger

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
                spacing: Appearance.padding.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

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
                        circle: true
                        // Normal: the critical red as hover chip; critical
                        // (red background): inverted near-white chip.
                        hoverColor: root.critical ? Appearance.colors.on_error_container : Appearance.colors.error_container
                        hoverContentColor: root.critical ? Appearance.colors.error_container : Appearance.colors.on_error_container
                        text: "×"
                        contentFontSize: Appearance.fontSize.xs
                        padding: Appearance.padding.small
                        verticalPadding: Appearance.padding.small
                        Layout.preferredWidth: implicitHeight
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
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
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
            // Defer so the Behavior animates the entrance from 0.
            Qt.callLater(() => root._shown = true);
            if (root.autoHideEnabled) {
                autoHideTimer.start();
            }
        }
    }

    // Runs after the exit fade; the row must stay alive until then.
    Timer {
        id: exitTimer
        interval: Appearance.anim.durations.small
        onTriggered: {
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

    function dismiss() {
        if (root._dismissed)
            return;
        root._dismissed = true;
        autoHideTimer.stop();
        root._shown = false;
        exitTimer.restart();
    }
}
