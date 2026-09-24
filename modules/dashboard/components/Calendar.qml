pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.components
import qs.config

Item {
    id: root

    property int month: (new Date()).getMonth()
    property int year: (new Date()).getFullYear()

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
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

        ColumnLayout {
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
                }
            }
        }
    }
}
