pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config

// Pane selector row for the console band header. Pane ids match
// ConsoleWindow.activePane. No clock: the bar shows one directly above.
RowLayout {
    id: root

    property string activePane: ""
    signal selectPane(string paneId)

    spacing: Appearance.spacing.small

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
            implicitHeight: Appearance.fontSize.xs + 8

            HudLabel {
                id: tagLabel
                anchors.verticalCenter: parent.verticalCenter
                accent: tag.active
                label: `${tag.modelData.index} ${tag.modelData.label}`
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectPane(tag.modelData.id)
            }
        }
    }

    Rule {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
    }
}
