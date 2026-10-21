pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config

// Tab row for a band-style window header (console, settings). `tabs` is
// `[{id, index, label}]` and `activePane` the active id. A pane with sub-views
// (the dashboard) hands its labels in through subLabels; they sit at the right
// end of the rule so the pane itself needs no header of its own. An optional
// `actionLabel` adds a trailing tag that only emits actionClicked. No clock:
// the bar shows one directly above.
RowLayout {
    id: root

    property var tabs: []
    property string activePane: ""
    property var subLabels: []
    property int subIndex: 0
    property string actionLabel: ""
    signal selectPane(string paneId)
    signal selectSub(int index)
    signal actionClicked

    spacing: Appearance.spacing.normal

    Repeater {
        model: root.tabs

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

    // Keeps the action from reading as one more sub-view tab.
    Rule {
        vertical: true
        visible: action.visible
        Layout.preferredHeight: Appearance.fontSize.xs + 6
        Layout.alignment: Qt.AlignVCenter
    }

    Item {
        id: action

        visible: root.actionLabel.length > 0
        implicitWidth: actionText.implicitWidth
        implicitHeight: Appearance.fontSize.xs + 14

        HudLabel {
            id: actionText
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            accent: actionMouse.containsMouse
            label: root.actionLabel

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked()
        }
    }
}
