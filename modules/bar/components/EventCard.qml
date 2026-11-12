pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services
import "EventTime.js" as ET

// Details card for the bar's next-event chip. Opened by a click and
// dismissed by any click or scroll outside it (the same backdrop pattern as
// TrayMenu); a hover popup was dropped because a missed pointer-leave left it
// stuck on screen. The chip owns creation, this destroys itself after the
// exit fade.
OverlayWindow {
    id: root

    property var chip: null
    // Horizontal centre of the chip in the bar window.
    property real anchorX: 0

    readonly property var ev: root.chip ? root.chip.upcoming : null
    readonly property date now: root.chip ? root.chip.now : new Date()
    readonly property int cardWidth: Appearance.spacing.large * 15
    readonly property int maxLater: 3

    readonly property bool ongoing: root.ev !== null && root.ev.start <= root.now.getTime() && root.ev.end > root.now.getTime()
    readonly property var later: {
        if (!root.ev)
            return [];
        const nowMs = root.now.getTime();
        const ev = root.ev;
        return CalendarEvents.eventsForDay(root.now).filter(e => e.end > nowMs && !(e.start === ev.start && e.title === ev.title));
    }

    signal willDestroy

    function rangeLabel() {
        if (!root.ev)
            return "";
        if (root.ev.allDay)
            return "All day";
        return `${CalendarEvents.formatTime(root.ev.start)} – ${CalendarEvents.formatTime(root.ev.end)}`;
    }

    function statusLabel() {
        if (!root.ev)
            return "";
        const nowMs = root.now.getTime();
        if (root.ongoing)
            return root.ev.allDay ? "" : `${ET.duration(Math.ceil((root.ev.end - nowMs) / 60000))} left`;
        return `in ${ET.duration(Math.ceil((root.ev.start - nowMs) / 60000))}`;
    }

    function progressValue() {
        if (!root.ev || !root.ongoing || root.ev.allDay)
            return 0;
        return (root.now.getTime() - root.ev.start) / (root.ev.end - root.ev.start);
    }

    function openDay() {
        if (root.ev)
            Dashboard.openDay(new Date(Math.max(root.ev.start, root.now.getTime())));
        root.closeAnimated();
    }

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    color: "transparent"
    aboveWindows: true
    focusable: false
    enterOffsetY: -8

    onEvChanged: {
        if (!root.ev && root.shown)
            root.closeAnimated();
    }

    onVisibleChanged: {
        if (!root.visible) {
            root.willDestroy();
            Qt.callLater(() => root.destroy());
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.closeAnimated()
        onWheel: root.closeAnimated()
    }

    Rectangle {
        id: card

        readonly property int margin: 8
        readonly property real screenWidth: root.screen ? root.screen.width : 1920

        x: Math.round(Math.max(margin, Math.min(root.anchorX - width / 2, screenWidth - width - margin)))
        // The overlay starts below the bar, so this is the same gap the
        // console band uses. (anchorY used to be added on top of the bar's
        // own height, which doubled the distance.)
        y: Appearance.barGap
        width: root.cardWidth
        height: col.implicitHeight + Appearance.padding.normal * 2
        opacity: root.animOpacity
        transform: Translate {
            y: root.animY
        }
        radius: Appearance.rounding.normal
        color: Appearance.colors.surface_container_high
        border.width: 1
        border.color: Appearance.colors.outline_variant

        // Clicks on the card itself must not reach the dismiss backdrop.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: col
            x: Appearance.padding.normal
            y: Appearance.padding.normal
            width: parent.width - Appearance.padding.normal * 2
            spacing: Appearance.padding.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.padding.small

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Appearance.padding.small
                    implicitHeight: Appearance.padding.small
                    radius: Appearance.rounding.full
                    color: (root.ev && root.ev.color) || Appearance.colors.primary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.ev ? root.ev.title : ""
                    font.pixelSize: Appearance.fontSize.sm
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.padding.small

                StyledText {
                    text: root.rangeLabel()
                    mono: true
                    color: Appearance.colors.on_surface_variant
                    font.pixelSize: Appearance.fontSize.xs
                }

                StyledText {
                    visible: text.length > 0
                    text: root.statusLabel() !== "" ? "· " + root.statusLabel() : ""
                    mono: true
                    color: Appearance.colors.primary
                    font.pixelSize: Appearance.fontSize.xs
                    font.weight: Font.DemiBold
                }
            }

            ProgressBar {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.padding.small
                visible: root.ongoing && root.ev !== null && !root.ev.allDay
                progress: root.progressValue()
            }

            Rule {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.padding.small
                visible: root.later.length > 0
            }

            HudLabel {
                visible: root.later.length > 0
                label: "Later today"
            }

            Repeater {
                model: root.later.slice(0, root.maxLater)

                delegate: RowLayout {
                    id: laterRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Appearance.padding.small

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Appearance.padding.small
                        implicitHeight: Appearance.padding.small
                        radius: Appearance.rounding.full
                        color: laterRow.modelData.color || Appearance.colors.primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: laterRow.modelData.title
                        font.pixelSize: Appearance.fontSize.sm
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: laterRow.modelData.allDay ? "All day" : CalendarEvents.formatTime(laterRow.modelData.start)
                        mono: true
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.xs
                    }
                }
            }

            StyledText {
                visible: root.later.length > root.maxLater
                text: `+${root.later.length - root.maxLater} more today`
                mono: true
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.xs
            }

            StyledButton {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.padding.small
                text: "Open day"
                onClicked: root.openDay()
            }
        }
    }
}
