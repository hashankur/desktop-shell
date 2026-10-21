pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.components
import qs.config
import qs.services
import qs.modules.launcher
import qs.modules.quicksettings
import qs.modules.powermenu
import qs.modules.dashboard
import qs.modules.theme

// Single console overlay: a full-width band under the bar hosting five
// exclusive panes (apps / ctrl / sys / pwr / theme). Replaces the separate
// overlay windows; services talk to it through per-service adapters, so
// QuickSettings / Dashboard / Session keep their window contract.
OverlayWindow {
    id: root

    // The band sits under the bar, so content enters from above.
    enterOffsetY: -40
    screen: Niri.focusedScreen
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusiveZone: 0
    aboveWindows: true
    focusable: true
    color: "transparent"

    property string activePane: "launcher"

    // Armed by showPane() (before the window maps) and dropped once the exit
    // fade unmaps it, so the lazy panes can load ahead of the open animation.
    property bool _live: false

    function paneLive(paneId) {
        return root._live && root.activePane === paneId;
    }

    onVisibleChanged: {
        if (!root.visible)
            root._live = false;
    }

    onShownChanged: {
        if (shown) {
            CalendarEvents.refreshIfStale();
            root.applyFocus();
        }
    }

    readonly property var paneOrder: ["launcher", "qs", "dashboard", "power", "theme"]

    function showPane(paneId) {
        // Only a switch while the console is up slides; the open animation
        // already covers the first appearance.
        const dir = Math.sign(root.paneOrder.indexOf(paneId) - root.paneOrder.indexOf(root.activePane));
        if (root.shown && dir !== 0)
            paneStack.enter(dir);
        root.activePane = paneId;
        root._live = true;
        // Services read their own requestedVisible in toggle(); mirror
        // the active pane so every open path (tabs, IPC, bar) agrees.
        QuickSettings.requestedVisible = paneId === "qs";
        Dashboard.requestedVisible = paneId === "dashboard";
        Session.requestedVisible = paneId === "power";
        root.applyFocus();
    }

    function openPane(paneId) {
        root.showPane(paneId);
        root.openAnimated();
    }

    function openLauncherPane(modeName) {
        root.showPane("launcher");
        launcherPane.openLauncher(modeName);
        root.applyFocus();
        root.openAnimated();
    }

    // Exactly two sanctioned focus grabs: the search field when the
    // launcher pane is active, the window content otherwise (panel
    // key handling then bubbles to the Keys handler below). On the very
    // first open the window is not mapped yet; SearchField.focus:true
    // plus the content FocusScope below catch activation: the scope
    // hands activeFocus down to the focused field. (content used to be
    // a plain Item with focus:true, which competed with the field on
    // activation and won, so typing needed a click first.)
    function applyFocus() {
        if (root.activePane === "launcher")
            launcherPane.focusSearch();
        else
            content.forceActiveFocus();
    }

    // Single close path: backdrop click, Esc, launcher actions, IPC.
    // Every service close funnels through an adapter's closeAnimated.
    function doClose() {
        qsAdapter.closeRequested();
        dashAdapter.closeRequested();
        Session.close();
    }

    function finishClose() {
        QuickSettings.requestedVisible = false;
        Dashboard.requestedVisible = false;
        Session.requestedVisible = false;
        root.closeAnimated();
    }

    QtObject {
        id: qsAdapter
        signal closeRequested
        function openAnimated() {
            root.openPane("qs");
        }
        function closeAnimated() {
            root.finishClose();
        }
    }

    QtObject {
        id: dashAdapter
        signal closeRequested
        function openAnimated() {
            root.openPane("dashboard");
        }
        function closeAnimated() {
            root.finishClose();
        }
        function openView(view) {
            root.showPane("dashboard");
            if (dashboardLoader.item)
                dashboardLoader.item.openView(view);
        }
    }

    QtObject {
        id: powerAdapter
        signal closeRequested
        function openAnimated() {
            root.openPane("power");
        }
        function closeAnimated() {
            root.finishClose();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            if (root.shown && root.activePane === "launcher")
                root.doClose();
            else
                root.openLauncherPane("apps");
        }

        function open() {
            root.openLauncherPane("apps");
        }

        function close() {
            root.doClose();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            if (root.shown && root.activePane === "launcher")
                root.doClose();
            else
                root.openLauncherPane("clipboard");
        }

        function open() {
            root.openLauncherPane("clipboard");
        }

        function close() {
            root.doClose();
        }
    }

    IpcHandler {
        target: "quicksettings"

        function toggle() {
            QuickSettings.toggle();
        }

        function open() {
            QuickSettings.open();
        }

        function close() {
            QuickSettings.close();
        }
    }

    IpcHandler {
        target: "powermenu"

        function toggle() {
            Session.toggle();
        }

        function open() {
            Session.open();
        }

        function close() {
            Session.close();
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            Dashboard.toggle();
        }

        function open(): void {
            Dashboard.open();
        }

        function openView(view: string): void {
            Dashboard.open(view);
        }

        function close(): void {
            Dashboard.close();
        }
    }

    IpcHandler {
        target: "theme"

        function toggle() {
            if (root.shown && root.activePane === "theme")
                root.doClose();
            else
                root.openPane("theme");
        }

        function open() {
            root.openPane("theme");
        }

        function close() {
            root.doClose();
        }
    }

    Component.onCompleted: {
        QuickSettings.setWindow(qsAdapter);
        Dashboard.setWindow(dashAdapter);
        Session.setWindow(powerAdapter);
    }

    // Click on transparent background to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: root.doClose()
    }

        // FocusScope: on window activation activeFocus resolves down the
        // scope chain to the search field when the launcher pane shows,
        // and stays on the scope itself otherwise so the Keys handler
        // receives Esc for every other pane.
        FocusScope {
            id: content
            anchors.fill: parent
            focus: true

        // Esc anywhere except the launcher search field (whose own
        // pipeline accepts first): power cancels a pending confirmation,
        // every other pane closes the console.
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                if (root.activePane === "power" && powerLoader.item && powerLoader.item.pendingAction !== "")
                    powerLoader.item.cancelAction();
                else
                    root.doClose();
                event.accepted = true;
            }
        }

        Item {
            id: band

            // One width for every pane: a card that resizes sideways on each
            // tab switch makes the header tabs jump under the cursor.
            readonly property int cap: 980

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Appearance.barGap
            width: Math.min(band.cap + Appearance.padding.large * 2, parent.width - Appearance.spacing.large * 2)
            height: bandColumn.implicitHeight + Appearance.padding.large * 2
            opacity: root.animOpacity
            transform: Translate {
                y: root.animY
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.surface_container_lowest
                border.width: 1
                border.color: Appearance.colors.outline_variant
                radius: Appearance.rounding.large
            }

            CornerFrame {
                anchors.fill: parent
                armLength: 16
                bracketColor: Appearance.colors.primary
            }

            // Prevent clicks inside the band from reaching the backdrop.
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: bandColumn

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: parent.width - Appearance.padding.large * 2
                spacing: Appearance.spacing.normal

                BandHeader {
                    Layout.fillWidth: true
                    activePane: root.activePane
                    subLabels: root.activePane === "dashboard" && dashboardLoader.item ? dashboardLoader.item.viewLabels : []
                    subIndex: dashboardLoader.item ? dashboardLoader.item.viewIndex : 0
                    onSelectPane: paneId => root.showPane(paneId)
                    onSelectSub: index => {
                        if (dashboardLoader.item)
                            dashboardLoader.item.openView(["overview", "system", "mpris"][index]);
                    }
                }

                // The band height follows the active pane and animates, so
                // switching panes resizes the card instead of snapping it.
                Item {
                    id: paneStack

                    readonly property var activeItem: {
                        switch (root.activePane) {
                        case "qs":
                            return qsLoader.item;
                        case "dashboard":
                            return dashboardLoader.item;
                        case "power":
                            return powerLoader.item;
                        case "theme":
                            return themeLoader.item;
                        default:
                            return launcherPane;
                        }
                    }
                    readonly property real wantHeight: activeItem ? activeItem.implicitHeight : 0

                    // Held while the next pane's Loader has no item yet, so
                    // the card never collapses to zero between panes.
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

                        // The launcher stays live (instant search, keeps its
                        // query). The other panes load only while active and
                        // the console is up: hidden they would keep
                        // re-evaluating bindings on SystemStats/CalendarEvents
                        // /Wifi and pin decoded textures.
                        LauncherPane {
                            id: launcherPane
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            visible: root.activePane === "launcher"
                            // Esc with the field focused, and every app/clipboard
                            // launch, arrive here as closeRequested.
                            onCloseRequested: root.doClose()
                        }

                        Loader {
                            id: qsLoader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: item ? item.implicitHeight : 0
                            visible: active
                            active: root.paneLive("qs")
                            sourceComponent: QuickSettingsPane {}
                        }

                        Loader {
                            id: dashboardLoader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: item ? item.implicitHeight : 0
                            visible: active
                            active: root.paneLive("dashboard")
                            sourceComponent: DashboardPane {}
                        }

                        Loader {
                            id: powerLoader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: item ? item.implicitHeight : 0
                            visible: active
                            active: root.paneLive("power")
                            sourceComponent: PowerPane {}
                        }

                        Loader {
                            id: themeLoader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: item ? item.implicitHeight : 0
                            visible: active
                            active: root.paneLive("theme")
                            sourceComponent: ThemePane {}
                        }
                    }
                }
            }
        }
    }
}
