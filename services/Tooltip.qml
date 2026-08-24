pragma Singleton

import QtQuick
import Quickshell

import qs.config

// Shared tooltip surface. There is one pointer, so there is one tooltip:
// coordinating it centrally lets the cursor travel between widgets without
// mapping/unmapping a window per widget (which reads as flicker).
Singleton {
    id: root

    // 0 = idle, 1 = armed (hover delay running), 2 = shown
    property int _phase: 0
    property var _item: null
    property string _requestedText: ""

    // Snapshot taken when shown; the live label rebinds to the active item.
    property string text: ""

    function request(item, text, delay) {
        // A re-request must always win: popup maps can emit a spurious
        // leave->enter pair, and dropping the re-enter would let a pending
        // hide fire while the cursor is still on the widget.
        hideTimer.stop();

        if (root._phase === 2 && root._item === item)
            return;

        root._item = item;
        root._requestedText = text;
        delayTimer.interval = Math.max(0, delay);
        root._phase = 1;
        delayTimer.restart();
    }

    function cancel(item) {
        if (root._item !== item)
            return;

        if (root._phase === 1) {
            delayTimer.stop();
            root._reset();
        } else if (root._phase === 2) {
            // Grace period: momentary hover loss should not blink the tooltip.
            hideTimer.restart();
        }
    }

    function revoke(item) {
        if (root._item !== item)
            return;
        delayTimer.stop();
        hideTimer.stop();
        popup.visible = false;
        root._reset();
    }

    function _reset() {
        root._item = null;
        root._requestedText = "";
        root._phase = 0;
    }

    function _show() {
        const item = root._item;
        if (item === null || root._requestedText === "") {
            root._reset();
            return;
        }

        // Set imperatively, immediately before showing: reactive bindings on
        // anchor.rect have been observed to evaluate against a stale/null
        // anchor.item across retargets, pinning the bubble onto the cursor.
        popup.anchor.item = item;
        popup.anchor.rect.x = 0;
        popup.anchor.rect.y = Math.round(item.height) + 8;

        root.text = root._requestedText;

        // Size the surface up front: live-bound surfaces resize (and flicker)
        // whenever reactive tooltip content changes while visible. The label
        // keeps updating inside the frozen surface until the next show.
        popup.implicitWidth = bubble.width;
        popup.implicitHeight = bubble.height;
        popup.visible = true;
        root._phase = 2;
    }

    Timer {
        id: delayTimer
        onTriggered: root._show()
    }

    Timer {
        id: hideTimer
        interval: 120
        onTriggered: {
            popup.visible = false;
            root._reset();
        }
    }

    PopupWindow {
        id: popup
        visible: false
        color: "transparent"

        // Never intercept pointer input: a popup under the cursor would cause
        // hover enter/leave churn on the widget that spawned it.
        mask: Region {}

        // Anchor point and size are assigned in _show(); see note there.

        // The compositor repositions the popup via xdg-popup constraint
        // adjustment when it would overflow.
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

        Rectangle {
            id: bubble
            width: bubbleText.width + 16
            height: bubbleText.height + 16
            radius: Appearance.rounding.small
            color: Appearance.colors.surface_container_high
            border.color: Appearance.colors.outline_variant
            border.width: 1

            Text {
                id: bubbleText
                x: 8
                y: 8
                width: Math.min(implicitWidth, 300)

                // Live-follow the active item's text, falling back to the
                // snapshot while transitioning.
                text: root._phase === 2 && root._item !== null ? root._item.text : root.text
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.fontSize.xs
                wrapMode: Text.Wrap
                color: Appearance.colors.on_surface
                elide: Text.ElideRight
                maximumLineCount: 10
            }
        }
    }
}
