pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import qs.config

Item {
    id: root

    property var model: []
    property int currentIndex: -1
    property int entryHeight: 64
    property int entrySpacing: 4
    property int maxVisibleEntries: 5
    property bool hasItems: false
    property int maxHeight: 480

    signal itemClicked(int index)

    readonly property int entriesCount: root.model.length
    readonly property int listHeight: entriesCount > 0 ? (entriesCount * entryHeight + (entriesCount - 1) * entrySpacing) : 0

    Layout.fillWidth: true
    Layout.preferredHeight: root.hasItems ? Math.min(root.listHeight, root.maxHeight) : 0
    Layout.maximumHeight: root.maxHeight
    opacity: root.hasItems ? 1 : 0
    visible: root.hasItems || opacity > 0
    clip: true

    Behavior on Layout.preferredHeight {
        NumberAnimation {
            duration: Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    ListView {
        id: listView
        anchors.fill: parent
        model: root.model
        currentIndex: root.currentIndex
        spacing: root.entrySpacing
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: ResultItem {
            required property var modelData
            required property int index

            primaryText: modelData.primaryText ?? ""
            secondaryText: modelData.secondaryText ?? ""
            iconSource: modelData.iconSource ?? ""
            thumbnailSource: modelData.thumbnailSource ?? ""
            hintText: (index < 5) ? ("Alt + " + (index + 1)) : ""
            isCurrent: index === listView.currentIndex
            entryIndex: index

            onEntered: {
                listView.currentIndex = index;
                root.currentIndex = index;
            }

            onClicked: {
                root.itemClicked(index);
            }
        }
    }
}
