import Quickshell
import QtQuick

import qs.components
import qs.config
import qs.services
import "EventTime.js" as ET

Rectangle {
    id: chip

    // Minute-resolution: the label and the card's status and progress all
    // recompute on every clock tick and whenever CalendarEvents rebuilds its
    // day index.
    readonly property date now: clock.date
    // Only an ongoing event shows no countdown, so this is almost always
    // non-empty, see restLabel().
    readonly property var upcoming: CalendarEvents.nextEvent(now)
    readonly property bool hovered: hoverHandler.hovered

    // Other events still live today, so a holiday or a single meeting does
    // not read as the whole day. Same filter as EventCard's "later" list.
    readonly property int othersToday: {
        const ev = upcoming;
        if (!ev)
            return 0;
        const nowMs = now.getTime();
        return CalendarEvents.eventsForDay(now).filter(e => e.end > nowMs && !(e.start === ev.start && e.title === ev.title)).length;
    }

    // Below this, the label switches from a minute countdown to a duration
    // and then to a weekday.
    readonly property int soonMinutes: 30

    // The open details card, if any (see EventCard.qml).
    property var _card: null

    visible: upcoming !== null
    // Explicitly transparent: the chip is now bare content over the bar, and
    // a Rectangle left at its default paints white.
    color: "transparent"
    implicitHeight: 22
    implicitWidth: chipRow.implicitWidth

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // nextEvent() is a pure read, so the chip owns its window: warm the
    // today...+8d range on creation and whenever the day rolls over.
    // Signal handlers run outside binding evaluation, so this cannot
    // re-create the dayMap write-during-read loop.
    function _warmWindow() {
        const base = clock.date;
        CalendarEvents.ensureWindow(base, new Date(base.getFullYear(), base.getMonth(), base.getDate() + 8));
    }

    onNowChanged: _warmWindow()
    Component.onCompleted: _warmWindow()

    Component {
        id: cardComponent

        EventCard {}
    }

    function toggleCard() {
        if (chip._card) {
            chip._card.closeAnimated();
            return;
        }
        // Map into the bar window so the card can centre on the chip; the
        // card itself is a screen-sized overlay on the same output.
        const win = chip.QsWindow.window;
        const p = win && win.contentItem ? chip.mapToItem(win.contentItem, chip.width / 2, 0) : Qt.point(chip.width / 2, 0);
        const props = {
            chip: chip,
            anchorX: p.x
        };
        if (win && win.screen)
            props.screen = win.screen;
        const card = cardComponent.createObject(chip, props);
        if (!card) {
            console.warn("NextEvent: failed to create event card");
            return;
        }
        chip._card = card;
        card.willDestroy.connect(() => {
            if (chip._card === card)
                chip._card = null;
        });
        card.openAnimated();
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.toggleCard()
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
            anchors.verticalCenterOffset: font.pixelSize / 10
            text: chip.restLabel()
            // No box to fill on hover, so the accent carries it: the label
            // takes the primary token and the bar's divider does the
            // separating. Token-driven, per the animation rules.
            color: hovered ? Appearance.colors.primary : Appearance.colors.on_surface
            mono: true
            font.pixelSize: Appearance.fontSize.sm
            font.weight: Font.DemiBold

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        // Hidden with no other events so it takes no room; the chip hugs
        // its content and the center group re-centers around it.
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: font.pixelSize / 10
            visible: chip.othersToday > 0
            text: `+${Math.min(chip.othersToday, 9)}`
            color: Appearance.colors.on_surface_variant
            mono: true
            font.pixelSize: Appearance.fontSize.sm
        }
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
            return `in ${ET.duration(mins)}`;
        const d = new Date(ev.start);
        return d.toLocaleDateString(Qt.locale(), daysAway(d) <= 6 ? "ddd" : "MMM d");
    }

    function daysAway(d) {
        const midnight = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
        return Math.round((midnight(d) - midnight(now)) / 86400000);
    }
}
