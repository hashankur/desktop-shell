pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.config
import qs.components

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
        id: hoverHandler

        onHoveredChanged: {
            if (hovered) {
                delayTimer.start();
            } else {
                delayTimer.stop();
                popup.visible = false;
            }
        }

        onPointChanged: {
            if (popup.visible) {
                var pos = point.position;
                popup.anchor.rect.x = Math.round(pos.x + 10);
                popup.anchor.rect.y = Math.round(pos.y + 20);
                popup.anchor.updateAnchor();
            }
        }
    }

    Timer {
        id: delayTimer
        interval: root.delay
        onTriggered: {
            if (root.text === "") return;

            var pos = hoverHandler.point.position;
            popup.anchor.item = root;
            popup.anchor.rect.x = Math.round(pos.x + 10);
            popup.anchor.rect.y = Math.round(pos.y + 20);
            popup.visible = true;
        }
    }

    PopupWindow {
        id: popup
        visible: false
        color: "transparent"

        Rectangle {
            id: tooltipBg
            width: tooltipText.width + 16
            height: tooltipText.height + 16
            radius: Appearance.rounding.small
            color: Appearance.colors.surface_container_high
            border.color: Appearance.colors.outline_variant
            border.width: 1

            StyledText {
                id: tooltipText
                x: 8
                y: 8
                width: Math.min(implicitWidth, 300)
                text: root.text
                font.pixelSize: Appearance.fontSize.xs
                wrapMode: Text.WordWrap
                color: Appearance.colors.on_surface
                elide: Text.ElideRight
                maximumLineCount: 10
            }
        }
    }
}
