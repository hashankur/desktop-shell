import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

import qs.components
import qs.config
import qs.services

Item {
    id: root
    property var notificationData
    property var notificationObject: null
    property int autoHideTimeout: notificationData?.timeout > 0 ? notificationData.timeout : 4000
    property bool autoHideEnabled: true
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

    width: Notifications.toastWidth
    // One line of body by default; an overflowing body expands in place.
    // bodyHeight is the single animated quantity: the body box follows it and
    // the toast grows by exactly its excess over one line (a taller chevron
    // button used to pad the collapsed row, so growth overshot).
    property bool expanded: false
    readonly property real bodyLine: bodyFull.lineCount > 0 ? bodyFull.contentHeight / bodyFull.lineCount : 0
    readonly property bool canExpand: bodyFull.lineCount > 1
    property real bodyHeight: root.expanded && root.canExpand ? bodyFull.contentHeight : root.bodyLine

    // Whole pixels only: the animation interpolates fractions, and a clip
    // rect or text origin landing between pixels makes the glyphs shimmer.
    readonly property int bodyShown: Math.ceil(root.bodyHeight)
    readonly property int lineShown: Math.ceil(root.bodyLine)

    implicitHeight: 100 + (root.bodyShown - root.lineShown)

    Behavior on bodyHeight {
        NumberAnimation {
            duration: Appearance.anim.durations.medium
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    function toggleExpanded() {
        root.expanded = !root.expanded;
        // An expanded toast is being read: it must not vanish under the cursor.
        if (root.expanded)
            autoHideTimer.stop();
        else if (root.autoHideEnabled && !root._dismissed)
            autoHideTimer.restart();
    }

    Rectangle {
        id: content
        anchors.fill: parent
        color: root.critical ? Appearance.colors.error_container : Appearance.colors.surface_container_low
        border.width: root.critical ? 0 : 1
        border.color: Appearance.colors.outline_variant
        radius: Appearance.rounding.normal
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
                radius: Appearance.rounding.normal
                color: "transparent"

                Image {
                    anchors.fill: parent
                    source: iconArea.resolvedImage
                    visible: iconArea.showImage
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    sourceSize: Qt.size(128, 128)
                    cache: false
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

                    HudLabel {
                        label: root.notificationData?.app || "Notification"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: Qt.formatDateTime(new Date(root.notificationData?.timestamp || Date.now()), "MMM d · h:mm AP")
                        mono: true
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.xs
                        Layout.alignment: Qt.AlignRight
                    }

                    StyledButton {
                        ghost: true
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

                // The chevron lives here, not in the header, so the header
                // (tag, date, close) is identical on every toast.
                RowLayout {
                    id: bodyRow
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Appearance.spacing.small

                    // Clip box whose height animates between one line and the
                    // whole body. Both texts stay laid out the whole time and
                    // crossfade, so the text never snaps while the box moves
                    // (swapping wrap mode / line limit mid-animation did).
                    Item {
                        id: bodyBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.bodyShown
                        Layout.alignment: Qt.AlignTop
                        clip: true

                        StyledText {
                            id: bodyOne
                            width: parent.width
                            text: root.notificationData?.body || ""
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: Appearance.fontSize.sm
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: root.expanded ? 0 : 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.durations.medium
                                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                                }
                            }
                        }

                        // Full wrapped body; also the measure for canExpand.
                        StyledText {
                            id: bodyFull
                            width: parent.width
                            text: bodyOne.text
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: Appearance.fontSize.sm
                            wrapMode: Text.Wrap
                            opacity: root.expanded ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.durations.medium
                                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                                }
                            }
                        }
                    }

                    // One body line tall and top-aligned, so it sits on the
                    // text line when collapsed. Opacity, not visible: the slot
                    // stays reserved on every toast, so the body width never
                    // depends on canExpand.
                    Item {
                        id: chevron
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 18
                        implicitHeight: root.lineShown
                        opacity: root.canExpand ? 1 : 0
                        enabled: root.canExpand

                        StyledText {
                            anchors.centerIn: parent
                            text: "▾"
                            font.pixelSize: Appearance.fontSize.xs
                            color: chevronMouse.containsMouse ? Appearance.colors.primary : Appearance.colors.on_surface_variant
                            rotation: root.expanded ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Appearance.anim.durations.medium
                                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.durations.small
                                    easing.bezierCurve: Appearance.anim.curves.standard
                                }
                            }
                        }

                        MouseArea {
                            id: chevronMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleExpanded()
                        }
                    }
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
