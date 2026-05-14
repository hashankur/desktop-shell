pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

import qs.components
import qs.config

Item {
    id: root

    readonly property var activePlayer: Mpris.players.values && Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property string artSource: albumArtSource(root.activePlayer)

    implicitWidth: parent.width
    implicitHeight: parent.height

    function albumArtSource(player) {
        if (!player) {
            return "";
        }

        var meta = player.metaData || player.metadata || player.metadataMap || {};
        if (meta["mpris:artUrl"]) {
            return meta["mpris:artUrl"];
        }
        if (meta["mpris:arturl"]) {
            return meta["mpris:arturl"];
        }
        if (player.artUrl) {
            return player.artUrl;
        }
        if (player.trackArtUrl) {
            return player.trackArtUrl;
        }

        return "";
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.surface_container_low
        border.color: Appearance.colors.surface_container
        border.width: 1

        Item {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large

            ColumnLayout {
                anchors.fill: parent
                spacing: Appearance.spacing.large

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Appearance.spacing.large

                    ClippingRectangle {
                        Layout.preferredWidth: 400
                        Layout.preferredHeight: 400
                        radius: Appearance.rounding.large
                        color: Appearance.colors.surface_container

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: root.activePlayer !== null && root.artSource !== ""
                            source: root.artSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !root.activePlayer || root.artSource === ""
                            color: Appearance.colors.surface_container_high

                            Icon {
                                anchors.centerIn: parent
                                source: Quickshell.iconPath("audio-x-generic-symbolic")
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Appearance.spacing.normal
                        Layout.margins: 20

                        Text {
                            text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown track") : "No media playing"
                            color: Appearance.colors.on_surface
                            font.family: Appearance.font.sans
                            font.pixelSize: Appearance.fontSize.extraLarge
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.activePlayer ? (root.activePlayer.trackArtist || "Unknown artist") : "Start playback to see album art and controls here."
                            color: Appearance.colors.on_surface_variant
                            font.family: Appearance.font.sans
                            font.pixelSize: Appearance.fontSize.large
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        Button {
                            text: root.activePlayer && root.activePlayer.isPlaying ? "Pause" : "Play"
                            enabled: root.activePlayer !== null
                            onClicked: {
                                if (root.activePlayer) {
                                    root.activePlayer.togglePlaying();
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root.activePlayer ? (root.activePlayer.appName || "Player") : ""
                                visible: root.activePlayer !== null
                                color: Appearance.colors.on_surface_variant
                                font.family: Appearance.font.sans
                                font.pixelSize: Appearance.fontSize.small
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.activePlayer && root.activePlayer.isPlaying ? "Playing" : "Paused"
                                visible: root.activePlayer !== null
                                color: Appearance.colors.on_surface_variant
                                font.family: Appearance.font.sans
                                font.pixelSize: Appearance.fontSize.small
                            }
                        }
                    }
                }
            }
        }
    }
}
