pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config

// Pane selector row for the console band header. Pane ids match
// ConsoleWindow.activePane. Panes with sub-views (the dashboard) hand their
// labels in through subLabels; they sit at the right end of the rule so the
// pane itself needs no header of its own. No clock: the bar shows one
// directly above.
RowLayout {
    id: root

    property string activePane: ""
    property var subLabels: []
    property int subIndex: 0
    signal selectPane(string paneId)
    signal selectSub(int index)

    spacing: Appearance.spacing.normal

    Repeater {
        model: [{
            id: "launcher",
            index: "01",
            label: "Apps"
        }, {
            id: "qs",
            index: "02",
            label: "Ctrl"
        }, {
            id: "dashboard",
            index: "03",
            label: "Sys"
        }, {
            id: "power",
            index: "04",
            label: "Pwr"
        }, {
            id: "theme",
            index: "05",
            label: "Theme"
        }]

        delegate: Item {
            id: tag

            required property var modelData
            required property int index

            readonly property bool active: root.activePane === modelData.id

            implicitWidth: tagLabel.implicitWidth
            implicitHeight: Appearance.fontSize.xs + 14

            HudLabel {
                id: tagLabel
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2
                accent: tag.active
                label: `${tag.modelData.index} ${tag.modelData.label}`
            }

            Rectangle {
                anchors.bottom: parent.bottom
                height: 2
                width: tag.active ? parent.width : 0
                color: Appearance.colors.primary

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.durations.small
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectPane(tag.modelData.id)
            }
        }
    }

    Rule {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
    }

    Repeater {
        model: root.subLabels

        delegate: Item {
            id: sub

            required property string modelData
            required property int index

            readonly property bool active: root.subIndex === index

            implicitWidth: subLabel.implicitWidth
            implicitHeight: Appearance.fontSize.xs + 14

            HudLabel {
                id: subLabel
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2
                accent: sub.active
                label: sub.modelData

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.durations.small
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                height: 2
                width: sub.active ? parent.width : 0
                color: Appearance.colors.primary

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.durations.small
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectSub(sub.index)
            }
        }
    }
}
