pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services
import "./components" as LauncherComponents

PanelWindow {
    id: root

    visible: false
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
    property int maxVisibleEntries: 5
    property int entryHeight: 64
    property int entrySpacing: 4
    property real revealProgress: 0.0

    Behavior on revealProgress {
        NumberAnimation {
            duration: Appearance.anim.durations.normal
            easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
        }
    }

    Timer {
        id: focusTimer
        interval: 0
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

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
                clipData.onEntriesChanged();
                updateListVisibility();
            }
        }
    }

    function openLauncher(modeName) {
        root.mode = modeName;

        if (!root.visible) {
            root.visible = true;
        }

        root.activeData.refresh();
        resetSearchState();
        root.updateResults("");
        focusTimer.restart();
    }

    function closeLauncher() {
        root.visible = false;
    }

    function resetSearchState() {
        searchField.text = "";
        root.activeData.reset();
        resultsList.model = [];
        resultsList.currentIndex = -1;
        resultsList.hasItems = false;
    }

    function updateResults(text) {
        root.activeData.filter(text);
        updateListVisibility();
    }

    function updateListVisibility() {
        var entries = root.activeData.foundEntries;
        resultsList.model = entries;
        resultsList.hasItems = entries.length > 0 && (root.mode === "clipboard" || searchField.text.trim().length > 0);
        resultsList.currentIndex = entries.length > 0 ? 0 : -1;
    }

    function activateCurrent() {
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
            if (root.visible)
                root.closeLauncher();
            else
                root.openLauncher("apps");
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            if (root.visible)
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

    onVisibleChanged: {
        if (visible) {
            revealProgress = 1;
            focusTimer.restart();
        } else {
            revealProgress = 0;
            clipData.cleanTempFiles();
        }
    }

    Rectangle {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.min(780, parent.width - Appearance.spacing.large * 2)
        height: Math.min(620, (Appearance.spacing.normal * 2) + 48 + (resultsList.hasItems ? (Appearance.spacing.normal + Math.min(resultsList.listHeight, resultsList.maxHeight)) : 0))
        radius: 22
        color: Appearance.colors.surface
        border.color: Appearance.colors.surface_bright

        ColumnLayout {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 10

            LauncherComponents.SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: root.activeData.placeholderText
                iconSource: root.activeData.iconSource
                maxVisibleEntries: root.activeData.maxVisibleEntries

        onSearchChanged: function (text) {
          root.updateResults(text);
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
                entryHeight: root.entryHeight
                entrySpacing: root.entrySpacing
                maxVisibleEntries: root.activeData.maxVisibleEntries
                maxHeight: root.mode === "clipboard" ? 480 : 320

                onItemClicked: function (index) {
                    root.activateAtIndex(index);
                }
            }
        }
    }

    Component.onCompleted: {
        appData.filter("");
    }
}
