import Quickshell
import QtQuick

import qs.components
import qs.config
import qs.services

Rectangle {
    id: chip

    // Minute-resolution: the label, card status and progress all recompute on
    // every clock tick and whenever CalendarEvents rebuilds its day index.
    readonly property date now: clock.date
    // Only an ongoing event shows no countdown, so this is almost always
    // non-empty, see restLabel().
    readonly property var upcoming: CalendarEvents.nextEvent(now)
    readonly property bool hovered: hoverHandler.hovered

    // Below this, the label switches from a minute countdown to a duration
    // and then to a weekday.
    readonly property int soonMinutes: 30

    // Flyout lifecycle mirrors OverlayWindow: `visible` lags behind on
    // exit so the fade can finish before the popup unmaps; _cardTarget
    // drives the animated properties below (never assign directly).
    property bool _cardTarget: false
    property bool _cardExit: false
    property real cardOpacity: _cardTarget ? 1 : 0
    property real cardY: _cardTarget ? 0 : -Appearance.spacing.small

    visible: upcoming !== null
    radius: Appearance.rounding.full
    color: hovered ? Appearance.colors.primary_container : "transparent"
    implicitHeight: 22
    implicitWidth: chipRow.implicitWidth + Appearance.padding.small * 2

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    Behavior on cardOpacity {
        NumberAnimation {
            duration: chip._cardTarget ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on cardY {
        NumberAnimation {
            duration: chip._cardTarget ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    onCardOpacityChanged: {
        // Exit finished: unmap. `<= 0` because the expressive curve
        // overshoots past the target.
        if (cardOpacity <= 0 && !_cardTarget) {
            _cardExit = false;
            card.visible = false;
        }
    }

    onUpcomingChanged: {
        if (!upcoming && (_cardTarget || _cardExit))
            closeCard();
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (chip.hovered) {
                hideTimer.stop();
                armTimer.restart();
            } else {
                armTimer.stop();
                if (chip._cardTarget || chip._cardExit)
                    hideTimer.restart();
            }
        }
    }

    Timer {
        id: armTimer
        interval: 200
        onTriggered: chip.openCard()
    }

    Timer {
        id: hideTimer
        interval: 120
        onTriggered: chip.closeCard()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Dashboard.toggle("overview");
            chip.closeCard();
        }
    }

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: Appearance.padding.small

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.padding.small
            height: Appearance.padding.small
            radius: Appearance.rounding.full
            color: (chip.upcoming && chip.upcoming.color) || Appearance.colors.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.restLabel()
            color: Appearance.colors.on_surface
            font.pixelSize: Appearance.fontSize.xs
            font.weight: Font.DemiBold
            // Fixed width and never hidden: the countdown changes text but
            // not footprint, so the clock cannot be nudged. (A Row skips
            // invisible children, so an empty-string guard here would change
            // the chip width the moment a label appears.)
            width: Appearance.spacing.large * 3
            elide: Text.ElideRight
        }
    }

    PopupWindow {
        id: card
        visible: false
        color: "transparent"

        // Live-bound: measuring/snapshotting at open time races the text
        // bindings' first layout pass and freezes a clipped height.
        implicitWidth: cardRoot.implicitWidth
        implicitHeight: cardRoot.implicitHeight

        // Same anchoring as services/Tooltip.qml: the anchor rect and
        // size are assigned in openCard() right before showing: live bindings
        // here have been observed to evaluate stale across retargets.
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

        onVisibleChanged: {
            if (!card.visible) {
                // The compositor dismissed the grab (click outside).
                chip._cardExit = false;
                chip._cardTarget = false;
            }
        }

        Item {
            id: cardRoot
            implicitWidth: Appearance.spacing.large * 15
            implicitHeight: cardCol.implicitHeight + Appearance.padding.normal * 2

            Rectangle {
                id: cardBg
                width: cardRoot.implicitWidth
                height: cardRoot.implicitHeight
                opacity: chip.cardOpacity
                y: chip.cardY
                radius: Appearance.rounding.normal
                color: Appearance.colors.surface_container_high
                border.color: Appearance.colors.outline_variant
                border.width: 1

                HoverHandler {
                    id: cardHover
                    onHoveredChanged: {
                        if (hovered) {
                            armTimer.stop();
                            hideTimer.stop();
                        } else if (chip._cardTarget) {
                            hideTimer.restart();
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Dashboard.toggle("overview");
                        chip.closeCard();
                    }
                }

                Column {
                    id: cardCol
                    x: Appearance.padding.normal
                    y: Appearance.padding.normal
                    width: cardRoot.implicitWidth - Appearance.padding.normal * 2
                    spacing: Appearance.padding.small

                    Row {
                        width: parent.width
                        spacing: Appearance.padding.small

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Appearance.padding.small
                            height: Appearance.padding.small
                            radius: Appearance.rounding.full
                            color: (chip.upcoming && chip.upcoming.color) || Appearance.colors.primary
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.upcoming ? chip.upcoming.title : ""
                            color: Appearance.colors.on_surface
                            font.pixelSize: Appearance.fontSize.sm
                            font.weight: Font.DemiBold
                            width: cardCol.width - Appearance.padding.small * 2
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        spacing: Appearance.padding.small

                        StyledText {
                            text: chip.rangeLabel()
                            color: Appearance.colors.on_surface_variant
                            font.pixelSize: Appearance.fontSize.xs
                        }

                        StyledText {
                            visible: text !== ""
                            text: chip.statusLabel() !== "" ? "· " + chip.statusLabel() : ""
                            color: Appearance.colors.primary
                            font.pixelSize: Appearance.fontSize.xs
                            font.weight: Font.DemiBold
                        }
                    }

                    ProgressBar {
                        width: parent.width
                        height: Appearance.padding.small
                        visible: chip.progressVisible()
                        progress: chip.progressValue()
                    }
                }
            }
        }
    }

    function openCard() {
        if (!visible || !upcoming)
            return;
        // Center under the chip: gravity grows rightward from the
        // anchor point, so shifting rect.x shifts the popup with it.
        // Both anchor.item and the rect are assigned imperatively right
        // before showing (Tooltip pattern): reactive bindings here have
        // been observed to evaluate stale across retargets.
        card.anchor.item = chip;
        card.anchor.rect.x = Math.round((width - cardRoot.implicitWidth) / 2);
        card.anchor.rect.y = Math.round(height) + 8;
        card.visible = true;
        _cardExit = false;
        _cardTarget = true;
    }

    function closeCard() {
        armTimer.stop();
        hideTimer.stop();
        if (!_cardTarget)
            return;
        _cardExit = true;
        _cardTarget = false;
    }

    // The chip label. Always something once the chip is visible, so a
    // week-away event is still readable instead of a bare colored dot.
    function restLabel() {
        const ev = upcoming;
        if (!ev)
            return "";
        const nowMs = now.getTime();
        if (ev.start <= nowMs && ev.end > nowMs)
            return ev.allDay ? "today" : "now";
        const mins = Math.ceil((ev.start - nowMs) / 60000);
        if (mins <= soonMinutes)
            return `in ${mins}m`;
        if (mins < 1440)
            return `in ${duration(mins)}`;
        const d = new Date(ev.start);
        return d.toLocaleDateString(Qt.locale(), daysAway(d) <= 6 ? "ddd" : "MMM d");
    }

    function daysAway(d) {
        const midnight = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
        return Math.round((midnight(d) - midnight(now)) / 86400000);
    }

    function statusLabel() {
        const ev = upcoming;
        if (!ev)
            return "";
        const nowMs = now.getTime();
        if (ev.start <= nowMs && ev.end > nowMs)
            return ev.allDay ? "" : `${duration(Math.ceil((ev.end - nowMs) / 60000))} left`;
        return `in ${duration(Math.ceil((ev.start - nowMs) / 60000))}`;
    }

    function duration(mins) {
        if (mins < 60)
            return `${mins}m`;
        if (mins < 1440) {
            const h = Math.floor(mins / 60);
            const m = mins % 60;
            return m ? `${h}h ${m}m` : `${h}h`;
        }
        return `${Math.ceil(mins / 1440)}d`;
    }

    function rangeLabel() {
        const ev = upcoming;
        if (!ev)
            return "";
        if (ev.allDay)
            return "All day";
        return `${CalendarEvents.formatTime(ev.start)} – ${CalendarEvents.formatTime(ev.end)}`;
    }

    function progressVisible() {
        const ev = upcoming;
        if (!ev || ev.allDay)
            return false;
        const nowMs = now.getTime();
        return ev.start <= nowMs && ev.end > nowMs;
    }

    function progressValue() {
        const ev = upcoming;
        if (!ev)
            return 0;
        const nowMs = now.getTime();
        if (nowMs < ev.start || nowMs > ev.end)
            return 0;
        return (nowMs - ev.start) / (ev.end - ev.start);
    }
}
