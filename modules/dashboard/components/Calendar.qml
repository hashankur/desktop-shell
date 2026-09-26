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

    property int month: (new Date()).getMonth()
    property int year: (new Date()).getFullYear()

    // Day drill-in (in-place, tray-menu pattern): the whole column slides
    // out, the content swaps, and the new content slides back in.
    property bool dayView: false
    property date selectedDate: new Date()
    property real slideX: 0
    property var _navCommit: null
    property real _navOut: 0
    property real _navIn: 0

    readonly property var dayEvents: root.dayView ? CalendarEvents.eventsForDay(root.selectedDate) : []

    function previousMonth() {
        if (root.month === 0) {
            root.month = 11;
            root.year--;
        } else {
            root.month--;
        }
    }

    function nextMonth() {
        if (root.month === 11) {
            root.month = 0;
            root.year++;
        } else {
            root.month++;
        }
    }

    function goToToday() {
        const now = new Date();
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
                        opacity: enabled ? 1 : 0.3
                    }
                    onClicked: root.previousMonth()
                }

                StyledButton {
                    ghost: true
                    padding: Appearance.padding.smaller
                    verticalPadding: Appearance.padding.smaller
                    contentItem: Icon {
                        source: Quickshell.iconPath("go-next-symbolic")
                        opacity: enabled ? 1 : 0.3
                    }
                    onClicked: root.nextMonth()
                }
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
                        opacity: enabled ? 1 : 0.3
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

                        // Up to 3 event dots along the bottom edge.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Appearance.padding.small
                            spacing: Appearance.padding.small / 2
                            visible: CalendarEvents.hasEvents(dayCard.dayData.date)

                            Repeater {
                                model: Math.min(3, CalendarEvents.eventsForDay(dayCard.dayData.date).length)

                                Rectangle {
                                    width: Appearance.padding.small
                                    height: Appearance.padding.small
                                    radius: Appearance.rounding.full
                                    color: Appearance.colors.primary
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
                                text: eventRow.modelData.allDay ? "All day" : Qt.formatDateTime(new Date(eventRow.modelData.start), "h:mm AP")
                                color: Appearance.colors.primary
                                font.pixelSize: Appearance.fontSize.xs
                                // Fixed time column, derived from a token so
                                // event titles line up without a magic width.
                                Layout.preferredWidth: Appearance.spacing.large * 4
                            }

                            StyledText {
                                text: eventRow.modelData.title
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
                            anchors.leftMargin: Appearance.spacing.large * 4 + Appearance.spacing.normal
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
