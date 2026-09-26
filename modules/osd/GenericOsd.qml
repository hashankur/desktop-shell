import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

/**
 * Generic OSD component that displays a progress indicator with an icon
 * Can be reused for volume, brightness, or any other sliding scale feedback
 *
 * Properties:
 * - iconPath: the icon source (e.g., Quickshell.iconPath("audio-volume-high-symbolic"))
 * - label: optional label text to display instead of or alongside the icon
 * - value: the current value (0.0 to 1.0)
 * - shouldShow: whether the OSD should be visible
 * - hideDelay: time in ms before the OSD hides (default 2000)
 * - onShouldShowChanged: emitted when visibility state changes
 */
Scope {
    id: root

    // Public properties
    property string iconPath: ""
    property string label: ""
    property real value: 0.0
    property bool shouldShow: false
    property int hideDelay: 2000
    // Unloads only after the exit fade finishes (see pill.onOpacityChanged),
    // so the window outlives `shouldShow` by the fade duration.
    property bool loaderActive: false

    Timer {
        id: hideTimer
        interval: root.hideDelay

        onTriggered: root.shouldShow = false
    }

    onShouldShowChanged: {
        if (root.shouldShow) {
            root.loaderActive = true;
            hideTimer.restart();
        }
    }

    // Show the pill (or extend it when already showing). Callers set
    // iconPath/value first, then bump via trigger() — assigning
    // `shouldShow = true` while already visible would be a no-op and
    // leave the hide timer untouched (mute toggles at constant volume).
    function trigger() {
        if (root.shouldShow)
            hideTimer.restart();
        else
            root.shouldShow = true;
    }

    // The OSD window will be created and destroyed based on shouldShow.
    // Using a LazyLoader reduces memory overhead when the window isn't open.
    LazyLoader {
        active: root.loaderActive

        PanelWindow {
            anchors.bottom: true
            screen: Niri.focusedScreen
            margins.bottom: screen.height / 10
            exclusiveZone: 0

            WlrLayershell.layer: WlrLayer.Overlay

            implicitWidth: 300
            implicitHeight: 50
            color: "transparent"

            // An empty click mask prevents the window from blocking mouse events.
            mask: Region {}

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: height / 2
                color: Appearance.colors.surface_container_lowest
                // Content state; deferred so the entrance animates from 0.
                property bool _in: false
                opacity: root.shouldShow && pill._in ? 1 : 0
                transform: Translate {
                    y: root.shouldShow && pill._in ? 0 : 12

                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.anim.durations.expressiveFastSpatial
                            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.expressiveFastSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }

                Component.onCompleted: Qt.callLater(() => pill._in = true)

                onOpacityChanged: {
                    // Exit fade done: drop the window (LazyLoader unloads it).
                    // `<= 0` because the expressive curve overshoots past the target.
                    if (opacity <= 0 && !root.shouldShow)
                        root.loaderActive = false;
                }

                border {
                    color: Appearance.colors.surface_container
                }

                RowLayout {
                    spacing: 10
                    anchors {
                        fill: parent
                        leftMargin: 20
                        rightMargin: 20
                    }

                    // Icon or label
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: iconRow.implicitWidth
                        implicitHeight: iconRow.implicitHeight

                        Row {
                            id: iconRow
                            spacing: 8

                            Icon {
                                visible: root.iconPath !== ""
                                Layout.alignment: Qt.AlignVCenter
                                source: root.iconPath
                            }

                            Text {
                                visible: root.label !== ""
                                text: root.label
                                color: Appearance.colors.on_surface
                                font.pixelSize: Appearance.fontSize.xs
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    // Progress bar
                    Rectangle {
                        // Stretches to fill all left-over space
                        Layout.fillWidth: true

                        implicitHeight: 20
                        radius: 20
                        color: Appearance.colors.surface_container

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }

                            // Cap value at 1.0 for display (prevents overflow for volume boost)
                            implicitWidth: parent.width * Math.min(1.0, root.value)
                            radius: parent.radius
                            color: Appearance.colors.primary

                            Behavior on implicitWidth {
                                NumberAnimation {
                                    duration: Appearance.anim.durations.medium
                                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
