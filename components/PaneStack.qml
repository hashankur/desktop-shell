import QtQuick
import QtQuick.Layouts

import qs.config

// Host for a window's pages: the card height follows the current page and
// animates, and `enter(dir)` slides the incoming page in from the side of
// travel. Pages are the children, anchored to the top and sized by their own
// implicitHeight; `current` is whichever of them is active (null while a
// lazy Loader has no item yet, which holds the last height).
Item {
    id: root

    property var current: null
    default property alias pages: slide.data

    readonly property real wantHeight: root.current ? root.current.implicitHeight : 0

    // Held while the next page's Loader has no item yet, so the card never
    // collapses to zero between pages.
    property real shownHeight: wantHeight

    onWantHeightChanged: {
        if (wantHeight > 0)
            shownHeight = wantHeight;
    }

    function enter(dir) {
        enterX.from = dir * 40;
        enterAnim.restart();
    }

    Layout.fillWidth: true
    Layout.preferredHeight: shownHeight
    clip: true

    Behavior on shownHeight {
        NumberAnimation {
            duration: Appearance.anim.durations.medium
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            id: enterX
            target: slide
            property: "x"
            to: 0
            duration: Appearance.anim.durations.expressiveFastSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }

        NumberAnimation {
            target: slide
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.anim.durations.expressiveFastSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Item {
        id: slide
        width: parent.width
        height: parent.height
    }
}
