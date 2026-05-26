pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.components
import qs.config

Item {
    id: root

    property int month: (new Date()).getMonth()
    property int year: (new Date()).getFullYear()

    implicitWidth: 400
    implicitHeight: 500

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
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: new Date().toLocaleString(Qt.locale(), "MMMM yyyy")
                    color: Appearance.colors.primary
                    font.family: Appearance.font.sans
                    font.pixelSize: Appearance.fontSize.xxl
                    font.weight: Font.Bold
                }

                Item {
                    Layout.fillWidth: true
                }

                ToolButton {
                    text: "chevron_left"
                    onClicked: root.previousMonth()
                }

                ToolButton {
                    // icon: {
                    //     name: "pan-start-symbolic"
                    //     height: 16
                    //     width: 16
                    // }
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
}
