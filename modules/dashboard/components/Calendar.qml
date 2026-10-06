pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

Item {
    id: root

    // Month navigation state. `_pinned` means "still showing today", which
    // lets the clock below roll the view over at midnight; paging away
    // unsticks it until Today is pressed.
    property int month: (new Date()).getMonth()
    property int year: (new Date()).getFullYear()
    property bool _pinned: true

    // Day drill-in (in-place, tray-menu pattern): the whole column slides
    // out, the content swaps, and the new content slides back in.
    property bool dayView: false
    property date selectedDate: new Date()
    property real slideX: 0
    property var _navCommit: null
    property real _navOut: 0
    property real _navIn: 0

    // Stable reference: CalendarEvents hands back the same sorted array until
    // the index actually changes, so a 15-minute refresh does not reset the
    // list and lose the scroll position.
    readonly property var dayEvents: root.dayView ? CalendarEvents.eventsForDay(root.selectedDate) : []

    SystemClock {
        id: calClock
        precision: SystemClock.Minutes
        onDateChanged: {
            if (!root._pinned)
                return;
            const today = calClock.date;
            root.month = today.getMonth();
            root.year = today.getFullYear();
            if (!root.dayView)
                root.selectedDate = today;
        }
    }

    // Expand the visible month up front so the dots are there on the first
    // frame instead of popping in a moment later.
    onMonthChanged: CalendarEvents.ensureMonth(root.year, root.month)
    onYearChanged: CalendarEvents.ensureMonth(root.year, root.month)
    Component.onCompleted: CalendarEvents.ensureMonth(root.year, root.month)

    function previousMonth() {
        root._pinned = false;
        if (root.month === 0) {
            root.month = 11;
            root.year--;
        } else {
            root.month--;
        }
    }

    function nextMonth() {
        root._pinned = false;
        if (root.month === 11) {
            root.month = 0;
            root.year++;
        } else {
            root.month++;
        }
    }

    function goToToday() {
        const now = new Date();
        root._pinned = true;
        root.month = now.getMonth();
        root.year = now.getFullYear();
    }

    function _transition(commit, forward) {
        root._navCommit = commit;
        root._navOut = (forward ? -1 : 1) * viewPort.width;
        root._navIn = (forward ? 1 : -1) * viewPort.width;
        navAnim.restart();
    }

    function openDay(date) {
        root._transition(() => {
            root.selectedDate = date;
            // The grid shows leading and trailing days from the neighbouring
            // months, so the header has to follow or the two disagree.
            if (!root.dayView) {
                root._pinned = false;
                root.month = date.getMonth();
                root.year = date.getFullYear();
            }
            root.dayView = true;
        }, true);
    }

    function navigateBack() {
        if (!root.dayView)
            return;
        root._transition(() => {
            root.dayView = false;
        }, false);
    }

    SequentialAnimation {
        id: navAnim

        NumberAnimation {
            target: root
            property: "slideX"
            to: root._navOut
            duration: Math.round(Appearance.anim.durations.small * 0.7)
            easing.bezierCurve: Appearance.anim.curves.standardAccel
        }

        ScriptAction {
            script: {
                if (root._navCommit) {
                    root._navCommit();
                    root._navCommit = null;
                }
            }
        }

        NumberAnimation {
            target: root
            property: "slideX"
            from: root._navIn
            to: 0
            duration: Math.round(Appearance.anim.durations.small * 0.7)
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    Item {
        id: viewPort
        anchors.fill: parent
        clip: true

        // Sliding page. Deliberately no anchors: anchors would override
        // the animated `x` (tray-menu slider pattern) — the layout margin
        // is folded into width/height and the static x/y offset instead.
        ColumnLayout {
            x: root.slideX + Appearance.padding.large
            y: Appearance.padding.large
            width: viewPort.width - Appearance.padding.large * 2
            height: viewPort.height - Appearance.padding.large * 2
            spacing: Appearance.spacing.normal

            // ── Month header ─────────────────────────────────────
            RowLayout {
                visible: !root.dayView
                Layout.fillWidth: true

                StyledText {
                    text: new Date(root.year, root.month, 1).toLocaleString(Qt.locale(), "MMMM yyyy")
                    color: Appearance.colors.primary
                    font.pixelSize: Appearance.fontSize.xxl
                    font.weight: Font.Bold
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledButton {
                    ghost: true
                    text: "Today"
                    padding: Appearance.padding.smaller
                    verticalPadding: Appearance.padding.smaller
                    onClicked: root.goToToday()
                }

                StyledButton {
                    ghost: true
                    padding: Appearance.padding.smaller
                    verticalPadding: Appearance.padding.smaller
                    contentItem: Icon {
                        source: Quickshell.iconPath("go-previous-symbolic")
                    }
                    onClicked: root.previousMonth()
                }

                StyledButton {
                    ghost: true
                    padding: Appearance.padding.smaller
                    verticalPadding: Appearance.padding.smaller
                    contentItem: Icon {
                        source: Quickshell.iconPath("go-next-symbolic")
                    }
                    onClicked: root.nextMonth()
                }
            }

            // A feed that could not be read keeps serving its last good text,
            // so nothing in the grid would otherwise reveal that the calendar
            // is out of date. Its own row, since the header has no slack.
            StyledText {
                visible: !root.dayView && CalendarEvents.fetchFailures.length > 0
                text: "Some calendars failed to update"
                color: Appearance.colors.error
                font.pixelSize: Appearance.fontSize.xs
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // ── Day header (drilled in) ──────────────────────────
            RowLayout {
                visible: root.dayView
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledButton {
                    ghost: true
                    padding: Appearance.padding.smaller
                    verticalPadding: Appearance.padding.smaller
                    contentItem: Icon {
                        source: Quickshell.iconPath("go-previous-symbolic")
                    }
                    onClicked: root.navigateBack()
                }

                StyledText {
                    text: root.selectedDate.toLocaleString(Qt.locale(), "ddd, MMM d")
                    color: Appearance.colors.primary
                    font.pixelSize: Appearance.fontSize.xxl
                    font.weight: Font.Bold
                }
            }

            // ── Month grid ───────────────────────────────────────
            ColumnLayout {
                visible: !root.dayView
                Layout.fillWidth: true
                Layout.fillHeight: true

                DayOfWeekRow {
                    locale: Qt.locale()
                    Layout.fillWidth: true

                    delegate: StyledText {
                        required property string shortName

                        text: shortName
                        color: Appearance.colors.on_surface
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        padding: 10
                    }
                }

                MonthGrid {
                    id: monthGrid
                    month: root.month
                    year: root.year
                    locale: Qt.locale()
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    delegate: Rectangle {
                        id: dayCard
                        required property var model
                        readonly property var dayData: model
                        readonly property string dayLabel: monthGrid.locale.toString(dayData.date, "d")
                        readonly property color dayTextColor: dayData.month === monthGrid.month ? Appearance.colors.on_surface : Appearance.colors.on_surface_variant
                        readonly property color dayBackgroundColor: dayData.today ? Appearance.colors.surface_container_high : "transparent"

                        radius: Appearance.rounding.full
                        color: dayBackgroundColor

                        StyledText {
                            anchors.centerIn: parent
                            text: dayCard.dayLabel
                            color: dayCard.dayTextColor
                            font.pixelSize: Appearance.fontSize.sm
                        }

                        // Up to 3 event dots along the bottom edge, each
                        // in its feed's calendar color.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Appearance.padding.small
                            spacing: Appearance.padding.small / 2
                            visible: CalendarEvents.hasEvents(dayCard.dayData.date)

                            Repeater {
                                model: CalendarEvents.eventsForDay(dayCard.dayData.date).slice(0, 3)

                                Rectangle {
                                    required property var modelData

                                    width: Appearance.padding.small
                                    height: Appearance.padding.small
                                    radius: Appearance.rounding.full
                                    color: modelData.color || Appearance.colors.primary
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openDay(dayCard.dayData.date)
                        }
                    }
                }
            }

            // ── Day events (drilled in) ──────────────────────────
            ColumnLayout {
                visible: root.dayView
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Appearance.spacing.normal

                ListView {
                    visible: root.dayEvents.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.dayEvents
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        id: eventRow
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        implicitHeight: rowContent.implicitHeight + Appearance.padding.normal

                        RowLayout {
                            id: rowContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Appearance.spacing.normal

                            StyledText {
                                text: eventRow.modelData.allDay
                                      ? "All day"
                                      : CalendarEvents.formatTime(eventRow.modelData.start)
                                color: Appearance.colors.primary
                                font.pixelSize: Appearance.fontSize.xs
                                elide: Text.ElideRight
                                // Fixed time column, derived from a token so
                                // event titles line up without a magic width.
                                Layout.preferredWidth: Appearance.spacing.large * 4
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                // implicit*, not width/height: this item is
                                // managed by the RowLayout.
                                implicitWidth: Appearance.padding.small
                                implicitHeight: Appearance.padding.small
                                radius: Appearance.rounding.full
                                color: eventRow.modelData.color || Appearance.colors.primary
                            }

                            StyledText {
                                text: eventRow.modelData.tentative
                                      ? eventRow.modelData.title + " (tentative)"
                                      : eventRow.modelData.title
                                color: eventRow.modelData.tentative
                                       ? Appearance.colors.on_surface_variant
                                       : Appearance.colors.on_surface
                                font.pixelSize: Appearance.fontSize.sm
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            visible: eventRow.index < root.dayEvents.length - 1
                            height: 1
                            color: Appearance.colors.outline_variant
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            // Starts at the title column: time + gap + dot + gap.
                            anchors.leftMargin: Appearance.spacing.large * 4 + Appearance.spacing.normal * 2 + Appearance.padding.small
                        }
                    }
                }

                Item {
                    visible: root.dayEvents.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StyledText {
                        anchors.centerIn: parent
                        text: "No events"
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.sm
                    }
                }
            }
        }
    }
}
