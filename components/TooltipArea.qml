pragma ComponentBehavior: Bound

import QtQuick

import qs.services

Item {
    id: root

    property string text: ""
    property int delay: 500

    default property alias content: contentItem.data

    implicitWidth: contentItem.childrenRect.width
    implicitHeight: contentItem.childrenRect.height

    Item {
        id: contentItem
        anchors.fill: parent
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                Tooltip.request(root, root.text, root.delay);
            else
                Tooltip.cancel(root);
        }
    }

    Component.onDestruction: Tooltip.revoke(root)
}
