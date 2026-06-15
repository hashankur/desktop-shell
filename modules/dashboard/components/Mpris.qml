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

    readonly property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players?.values.filter(player => player.identity === "Spotify")[0] : null
    readonly property string artUrl: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""

    implicitWidth: parent.width
    implicitHeight: parent.height

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.large
        anchors.bottom: parent.bottom

        ClippingRectangle {
            Layout.preferredWidth: 420
            Layout.preferredHeight: 420
            radius: Appearance.rounding.small
            color: Appearance.colors.surface_container

            Image {
                anchors.fill: parent
                visible: root.artUrl !== ""
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                retainWhileLoading: true
            }

            Rectangle {
                anchors.fill: parent
                visible: root.artUrl === ""
                color: Appearance.colors.surface_container_high

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 64
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
                text: root.activePlayer ? (root.activePlayer?.trackTitle || "Unknown track") : "No media playing"
                color: Appearance.colors.on_surface
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.fontSize.xxxl
                font.weight: Font.Black
                wrapMode: Text.WordWrap
            }

            Text {
                text: root.activePlayer ? (root.activePlayer?.trackArtist || "Unknown artist") : "Start playback to see album art and controls here."
                color: Appearance.colors.on_surface_variant
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.fontSize.xl
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                text: root.activePlayer ? root.activePlayer?.trackAlbum : ""
                color: Appearance.colors.on_surface_variant
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.fontSize.lg
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
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
        }
    }
}
