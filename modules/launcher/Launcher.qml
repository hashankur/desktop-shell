pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.components
import qs.config
import qs.services
import "./components" as LauncherComponents

OverlayWindow {
    id: root

    // Content slides up from below on enter, back down on exit.
    enterOffsetY: 40
    screen: Niri.focusedScreen
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    margins {
        bottom: Appearance.spacing.large
    }
    aboveWindows: true
    focusable: true
    color: "transparent"

    property string mode: "apps"
    property int entrySpacing: 4

    LauncherComponents.AppModeData {
        id: appData
    }
    LauncherComponents.ClipboardModeData {
        id: clipData
    }

    property var activeData: root.mode === "clipboard" ? clipData : appData

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            if (root.mode === "clipboard") {
                clipData.handleEntriesChanged();
                updateListVisibility();
            }
        }
    }

    Connections {
        target: clipData
        function onThumbnailsUpdated() {
            // Refresh without resetting keyboard selection.
            updateListVisibility(false);
        }
    }

    Timer {
        id: searchDebounce
        interval: 80
        onTriggered: root.updateResults(searchField.text)
    }

    function openLauncher(modeName) {
        root.mode = modeName;

        if (!root.shown) {
            root.openAnimated();
        }

        root.activeData.refresh();
        root.activeData.reset();
        searchField.clear();
        root.updateResults("");
    }

    function closeLauncher() {
        root.closeAnimated();
    }

    function updateResults(text) {
        root.activeData.filter(text);
        updateListVisibility();
    }

    function updateListVisibility(resetSelection = true) {
        var entries = root.activeData.foundEntries;
        // A fresh array reference forces the ListView to reload; assigning
        // the same (mutated) array is deduped and thumbnails never appear.
        resultsList.model = entries.slice();
        resultsList.hasItems = entries.length > 0;
        if (resetSelection) {
            resultsList.currentIndex = entries.length > 0 ? 0 : -1;
        } else if (resultsList.currentIndex >= entries.length) {
            resultsList.currentIndex = entries.length > 0 ? entries.length - 1 : -1;
        }
    }

    function activateCurrent() {
        if (searchDebounce.running) {
            searchDebounce.stop();
            root.updateResults(searchField.text);
        }
        if (resultsList.currentIndex >= 0) {
            root.activeData.activate(resultsList.currentIndex);
            root.closeLauncher();
        }
    }

    function activateAtIndex(index) {
        if (index >= 0 && index < root.activeData.foundEntries.length) {
            root.activeData.activate(index);
            root.closeLauncher();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            if (root.shown)
                root.closeLauncher();
            else
                root.openLauncher("apps");
        }

        function open() {
            root.openLauncher("apps");
        }

        function close() {
            root.closeLauncher();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            if (root.shown)
                root.closeLauncher();
            else
                root.openLauncher("clipboard");
        }

        function open() {
            root.openLauncher("clipboard");
        }

        function close() {
            root.closeLauncher();
        }
    }

    // Click on transparent background to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeLauncher()
    }

    Rectangle {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.min(780, parent.width - Appearance.spacing.large * 2)
        height: Math.min(500, (Appearance.spacing.normal * 2) + 48 + (resultsList.hasItems ? (Appearance.spacing.normal + resultsList.listHeight) : 0))
        radius: Appearance.rounding.large
        color: Appearance.colors.surface
        border.color: Appearance.colors.surface_bright
        opacity: root.animOpacity
        transform: Translate {
            y: root.animY
        }

        // Must animate in lockstep with ResultsList's Layout.preferredHeight
        // Behavior (identical trigger, duration, curve): otherwise the
        // background snaps to the new size while the list still animates,
        // which reads as jank when the result count shrinks.
        Behavior on height {
            NumberAnimation {
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
        }

        // Prevent clicks inside the frame from closing the launcher
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 10

            LauncherComponents.SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: root.activeData.placeholderText
                iconSource: root.activeData.iconSource
                maxVisibleEntries: root.activeData.maxVisibleEntries

                onSearchChanged: {
                    searchDebounce.restart();
                }

                onAccepted: root.activateCurrent()

                onUpPressed: {
                    if (resultsList.entriesCount > 0) {
                        resultsList.currentIndex = Math.max(0, resultsList.currentIndex - 1);
                    }
                }

                onDownPressed: {
                    if (resultsList.entriesCount > 0) {
                        resultsList.currentIndex = Math.min(resultsList.entriesCount - 1, resultsList.currentIndex + 1);
                    }
                }

                onEscapePressed: root.closeLauncher()

                onAltNumberPressed: function (index) {
                    root.activateAtIndex(index);
                }
            }

            LauncherComponents.ResultsList {
                id: resultsList
                entryHeight: root.activeData.entryHeight
                entrySpacing: root.entrySpacing
                maxVisibleEntries: root.activeData.maxVisibleEntries
                pinsEnabled: root.mode === "apps"

                onItemClicked: function (index) {
                    root.activateAtIndex(index);
                }

                onPinToggled: function (desktopId) {
                    AppLibrary.togglePin(desktopId);
                    root.updateResults(searchField.text);
                    // Pinning reorders the list; keep selection on the same app.
                    for (var i = 0; i < root.activeData.foundEntries.length; i++) {
                        if (root.activeData.foundEntries[i]._desktopId === desktopId) {
                            resultsList.currentIndex = i;
                            break;
                        }
                    }
                }
            }
        }
    }
}
