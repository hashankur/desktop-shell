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

    // The Tooltip singleton is created on first use. Touching it from
    // onDestruction when this area never requested anything would create it
    // mid-teardown (shell reload or exit) and crash Qt inside Text layout, so
    // only revoke what was actually requested.
    property bool _requested: false

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                root._requested = true;
                Tooltip.request(root, root.text, root.delay);
            } else if (root._requested) {
                Tooltip.cancel(root);
            }
        }
    }

    Component.onDestruction: {
        if (root._requested)
            Tooltip.revoke(root);
    }
}
