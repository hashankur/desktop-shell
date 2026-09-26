pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.config

// Base for the fullscreen transparent overlay windows (launcher,
// dashboard, quick settings, power menu, tray menu). Callers drive
// openAnimated()/closeAnimated() instead of assigning `visible`, so
// enter/exit can fade (and, via animY, slide):
//
// - open maps the window and animates opacity 0->1 (and animY to 0);
// - close keeps it mapped until the exit animation finishes
//   (_exitActive), then unmaps;
// - re-opening mid-fade animates back from the current value.
//
// Bind each window's content panel to `opacity: root.animOpacity` and
// `transform: Translate { y: root.animY }`; the slide distance/direction
// comes from `enterOffsetY` (positive = enters from below, negative =
// from above).
PanelWindow {
    id: root

    // Target visibility; `visible` lags behind on exit so the fade can
    // finish before the layer surface unmaps.
    property bool _target: false
    property bool _exitActive: false

    // px the content rests offset from its open position while exiting
    // (and starts at, while entering).
    property real enterOffsetY: 0

    // Drive content bindings from these; animated via the Behaviors below.
    // Not readonly purely because Behavior attaches to writable properties —
    // never assign to them directly.
    property real animOpacity: _target ? 1 : 0
    property real animY: _target ? 0 : enterOffsetY

    // IPC/service code checks this instead of `visible`, which stays true
    // for the duration of the exit fade.
    readonly property bool shown: _target

    visible: _target || _exitActive

    function openAnimated() {
        root._target = true;
        root._exitActive = false;
    }

    function closeAnimated() {
        if (!root._target)
            return;
        root._exitActive = true;
        root._target = false;
    }

    // Both Behaviors share duration + curve + trigger, so fade and slide
    // stay locked to the same progress (caelestia pattern): enter springs
    // in with slight overshoot, exit snaps out just as fast instead of
    // lingering under an accel-out fade.
    Behavior on animOpacity {
        NumberAnimation {
            duration: root._target ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on animY {
        NumberAnimation {
            duration: root._target ? Appearance.anim.durations.expressiveFastSpatial : Appearance.anim.durations.small
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    onAnimOpacityChanged: {
        // Exit finished: drop the mapping reference so the window unmaps.
        // `<= 0` because the expressive curve overshoots past the target.
        if (root.animOpacity <= 0 && !root._target)
            root._exitActive = false;
    }
}
