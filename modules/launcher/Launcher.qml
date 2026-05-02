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
        left: Appearance.spacing.large * 2
        right: Appearance.spacing.large * 2
        top: Appearance.spacing.large * 2
        bottom: Appearance.spacing.large * 2
    }
    aboveWindows: true
    focusable: true
    color: "transparent"

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

        searchField.text = "";
        listView.currentIndex = 0;
        updateResults();
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
            focusTimer.restart();
        } else {
            searchField.text = "";
            updateResults();
            listView.currentIndex = 0;
        }
    }

    Rectangle {
        id: frame
        anchors.centerIn: parent
        width: Math.min(920, parent.width - Appearance.spacing.large * 4)
        height: Math.min(640, parent.height - Appearance.spacing.large * 4)
        radius: Appearance.rounding.large
        color: Appearance.colors.surface_container_lowest
        border.color: Appearance.colors.outline_variant
        border.width: 1

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: Appearance.spacing.large
            }
            spacing: Appearance.spacing.normal

            // Search field
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: Appearance.rounding.normal
                color: Appearance.colors.surface_container
                border.color: Appearance.colors.surface_container_high
                border.width: 1

                TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    background: Rectangle { color: "transparent" }
                    placeholderText: "Search applications..."
                    font.pixelSize: Appearance.fontSize.normal
                    color: Appearance.colors.on_surface
                    placeholderTextColor: Appearance.colors.on_surface_variant
                    focus: true
                    activeFocusOnTab: true

                    onTextChanged: updateResults()
                    Keys.onEnterPressed: launchCurrent()
                    Keys.onDownPressed: {
                        if (listView.count > 0) {
                            listView.incrementCurrentIndex();
                            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                        }
                    }
                    Keys.onUpPressed: {
                        if (listView.count > 0) {
                            listView.decrementCurrentIndex();
                            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
                        }
                    }
                    Keys.onEscapePressed: launcher.closeLauncher()
                }
            }

            // Results list
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Appearance.colors.surface_container
                clip: true

                ScrollView {
                    anchors {
                        fill: parent
                        margins: 1
                    }
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ListView {
                        id: listView
                        model: foundEntries
                        currentIndex: 0
                        spacing: Appearance.spacing.small

                        delegate: Rectangle {
                            id: delegate
                            required property DesktopEntry modelData
                            required property int index

                            width: ListView.view.width
                            height: 50
                            color: index === listView.currentIndex
                                ? Appearance.colors.surface_container_high
                                : (mouseArea.containsMouse
                                    ? Appearance.colors.surface_container_high
                                    : "transparent")
                            radius: Appearance.rounding.small

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    margins: Appearance.padding.normal
                                }
                                spacing: Appearance.spacing.normal

                                IconImage {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    source: Quickshell.iconPath(delegate.modelData.icon, true)
                                    visible: source !== ""
                                }

                                Text {
                                    text: delegate.modelData.name
                                    color: Appearance.colors.on_surface
                                    font.pixelSize: Appearance.fontSize.normal
                                    font.family: Appearance.font.sans
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: delegate.modelData.comment ?? ""
                                    color: Appearance.colors.on_surface_variant
                                    font.pixelSize: Appearance.fontSize.smaller
                                    font.family: Appearance.font.sans
                                    Layout.preferredWidth: 200
                                    elide: Text.ElideRight
                                    visible: delegate.modelData.comment !== ""
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
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
    }

    // Application list management
    property list<DesktopEntry> foundEntries: DesktopEntries.applications.values

    function updateResults() {
        const query = searchField.text.toLowerCase().trim();
        if (query === "") {
            foundEntries = DesktopEntries.applications.values;
        } else {
            foundEntries = DesktopEntries.applications.values.filter(app => 
                app.name.toLowerCase().includes(query) || 
                (app.comment?.toLowerCase().includes(query) ?? false)
            );
        }
        listView.currentIndex = foundEntries.length > 0 ? 0 : -1;
    }

    function launchCurrent() {
        if (listView.currentIndex >= 0 && listView.currentIndex < listView.count) {
            foundEntries[listView.currentIndex].execute();
            launcher.closeLauncher();
            searchField.text = "";
        }
    }

    Component.onCompleted: {
        updateResults();
    }
}
