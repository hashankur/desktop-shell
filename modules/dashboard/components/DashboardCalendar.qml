pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.config

Item {
    id: root

    property int month: (new Date()).getMonth()
    property int year: (new Date()).getFullYear()

    implicitWidth: 390
    implicitHeight: 520

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

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.surface_container_low
        border.color: Appearance.colors.surface_container
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true

                ToolButton {
                    text: "chevron_left"
                    onClicked: root.previousMonth()
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Qt.formatDate(new Date(root.year, root.month, 1), Qt.locale(), "MMMM yyyy")
                    color: Appearance.colors.on_surface
                    font.family: Appearance.font.sans
                    font.pixelSize: Appearance.fontSize.large
                    font.weight: Font.Medium
                }

                Item {
                    Layout.fillWidth: true
                }

                ToolButton {
                    text: "chevron_right"
                    onClicked: root.nextMonth()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                DayOfWeekRow {
                    locale: Qt.locale()
                    Layout.alignment: Qt.AlignHCenter
                }

                MonthGrid {
                    id: monthGrid
                    month: root.month
                    year: root.year
                    locale: Qt.locale()
                    Layout.fillWidth: true
                    Layout.preferredHeight: 360

                    delegate: Rectangle {
                        id: dayCard
                        required property var model
                        readonly property var dayData: model
                        readonly property string dayLabel: monthGrid.locale.toString(dayData.date, "d")
                        readonly property color dayTextColor: dayData.month === monthGrid.month ? Appearance.colors.on_surface : Appearance.colors.on_surface_variant
                        readonly property color dayBackgroundColor: dayData.today ? Appearance.colors.surface_container_high : "transparent"

                        width: monthGrid.width / 7
                        height: 42
                        radius: Appearance.rounding.small
                        color: dayBackgroundColor

                        Text {
                            anchors.centerIn: parent
                            text: dayCard.dayLabel
                            color: dayCard.dayTextColor
                            font.family: Appearance.font.sans
                            font.pixelSize: Appearance.fontSize.normal
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
