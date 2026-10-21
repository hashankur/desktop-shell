pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services
import "./components" as LauncherComponents

// Launcher pane for the console band. The window shell (IPC, backdrop,
// screen geometry, focus handoff) lives in modules/console/ConsoleWindow.qml.
Item {
    id: root

    signal closeRequested

    property string mode: "apps"
    property int entrySpacing: 4

    // Exact content height (2x margins + the column's own implicit
    // height). A fixed cap undershot the result list's clamped height
    // (listHeight is raw and unbounded; the list clamps at 480), which
    // spilled rows past the band card on any list longer than ~6.
    implicitHeight: mainColumn.implicitHeight + Appearance.spacing.smaller * 2

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
        root.activeData.refresh();
        root.activeData.reset();
        searchField.clear();
        root.updateResults("");
    }

    function closeLauncher() {
        root.closeRequested();
    }

    function focusSearch() {
        searchField.focusField();
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

    ColumnLayout {
        id: mainColumn
        anchors {
            fill: parent
            margins: Appearance.spacing.smaller
        }
        spacing: Appearance.spacing.smaller

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            HudLabel {
                label: root.mode === "apps" ? "LAUNCHER // APPS" : "LAUNCHER // CLIP"
            }

            Rule {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            HudLabel {
                accent: true
                label: `${root.activeData.foundEntries.length} entries`
            }
        }

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
