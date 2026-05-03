pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import qs.components
import qs.config

PanelWindow {
    id: launcher
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

    property int maxVisibleEntries: 5
    property int entryHeight: 64
    property int entrySpacing: 4
    property real revealProgress: 0.0
    readonly property bool hasQuery: searchField.text.trim().length > 0
    readonly property int visibleEntryCount: Math.min(maxVisibleEntries, foundEntries.length)
    readonly property int listHeight: visibleEntryCount > 0
        ? (visibleEntryCount * entryHeight + (visibleEntryCount - 1) * entrySpacing)
        : 0

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

    function openLauncher() {
        if (!launcher.visible) {
            launcher.visible = true;
        }

        resetSearchState();
        focusTimer.restart();
    }

    function closeLauncher() {
        launcher.visible = false;
    }

    // IPC for external control
    IpcHandler {
        target: "launcher"

        function toggle() {
            if (launcher.visible) launcher.closeLauncher();
            else launcher.openLauncher();
        }
    }

    onVisibleChanged: {
        if (visible) {
            revealProgress = 1;
            focusTimer.restart();
        } else {
            revealProgress = 0;
            resetSearchState();
        }
    }

    Rectangle {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.min(780, parent.width - Appearance.spacing.large * 2)
        height: Math.min(
            620,
            (Appearance.spacing.normal * 2) + 48 + (launcher.hasQuery ? (Appearance.spacing.normal + launcher.listHeight) : 0)
        )
        radius: 22
        color: Appearance.colors.surface_container_lowest
        border.color: Appearance.colors.surface_container

        ColumnLayout {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 10

            // Search field
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 24
                color: Appearance.colors.surface_container

                IconImage {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    width: 18
                    height: 18
                    source: Quickshell.iconPath("system-search-symbolic", true)
                }

                TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.leftMargin: 42
                    anchors.rightMargin: 12
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    background: Rectangle { color: "transparent" }
                    placeholderText: "Search applications..."
                    font.pixelSize: Appearance.fontSize.normal
                    color: Appearance.colors.on_surface
                    placeholderTextColor: Appearance.colors.on_surface_variant
                    focus: true
                    activeFocusOnTab: true

                    onTextChanged: updateResults()
                    onAccepted: launchCurrent()
                    Keys.onEnterPressed: launchCurrent()
                    Keys.onReturnPressed: launchCurrent()
                    Keys.onPressed: function(event) {
                        if (!(event.modifiers & Qt.AltModifier)) return;
                        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                            const targetIndex = event.key - Qt.Key_1;
                            launchAtIndex(targetIndex);
                            event.accepted = true;
                        }
                    }
                    Keys.onDownPressed: {
                        if (listView.count > 0) {
                            listView.incrementCurrentIndex();
                        }
                    }
                    Keys.onUpPressed: {
                        if (listView.count > 0) {
                            listView.decrementCurrentIndex();
                        }
                    }
                    Keys.onEscapePressed: launcher.closeLauncher()
                }
            }

            // Results list
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: launcher.hasQuery ? launcher.listHeight : 0
                opacity: launcher.hasQuery ? 1 : 0
                visible: launcher.hasQuery || opacity > 0
                clip: true

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: Appearance.anim.durations.small
                        easing.bezierCurve: Appearance.anim.curves.standardDecel
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.small
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }

                ListView {
                    id: listView
                    anchors.fill: parent
                    model: foundEntries
                    currentIndex: foundEntries.length > 0 ? 0 : -1
                    spacing: launcher.entrySpacing
                    clip: true
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: delegate
                        required property DesktopEntry modelData
                        required property int index

                        width: ListView.view.width
                        height: launcher.entryHeight
                        color: index === listView.currentIndex
                            ? Appearance.colors.surface_container
                            : "transparent"
                        radius: 10

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                margins: Appearance.padding.normal
                            }
                            spacing: Appearance.spacing.large

                            IconImage {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                source: Quickshell.iconPath(delegate.modelData.icon, true)
                                visible: source !== ""
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: delegate.modelData.name
                                    color: Appearance.colors.on_surface
                                    font.pixelSize: Appearance.fontSize.large
                                    font.weight: Font.DemiBold
                                    font.family: Appearance.font.sans
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: delegate.modelData.comment ?? delegate.modelData.name
                                    color: Appearance.colors.on_surface_variant
                                    font.pixelSize: Appearance.fontSize.normal
                                    font.family: Appearance.font.sans
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                    width: 500
                                }
                            }

                            Text {
                                text: "Alt " + (index + 1)
                                color: Appearance.colors.on_surface
                                font.pixelSize: Appearance.fontSize.normal
                                font.family: Appearance.font.sans
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                Layout.preferredWidth: 56
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: listView.currentIndex = delegate.index
                            onClicked: {
                                delegate.modelData.execute();
                                launcher.closeLauncher();
                            }
                        }
                    }
                }
            }
        }
    }

    // Application list management
    property list<DesktopEntry> foundEntries: []

    function resetSearchState() {
        searchField.text = "";
        foundEntries = [];
        listView.currentIndex = -1;
    }

    function updateResults() {
        const query = searchField.text.toLowerCase().trim();
        if (query === "") {
            foundEntries = [];
        } else {
            foundEntries = DesktopEntries.applications.values
                .filter(app =>
                    app.name.toLowerCase().includes(query)
                    || (app.comment?.toLowerCase().includes(query) ?? false)
                )
                .slice(0, launcher.maxVisibleEntries);
        }
        listView.currentIndex = foundEntries.length > 0 ? 0 : -1;
    }

    function launchAtIndex(index) {
        if (index >= 0 && index < foundEntries.length) {
            foundEntries[index].execute();
            launcher.closeLauncher();
            searchField.text = "";
        }
    }

    function launchCurrent() {
        launchAtIndex(listView.currentIndex);
    }

    Component.onCompleted: {
        updateResults();
    }
}
