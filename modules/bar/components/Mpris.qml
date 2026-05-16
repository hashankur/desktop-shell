import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

Row {
    id: root

    // Get the active/current player from the values array
    readonly property var activePlayer: Mpris.players.values && Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool isSpotify: {
        if (!activePlayer) {
            return false
        }

        var app = (activePlayer.appName || "").toLowerCase()
        var identity = (activePlayer.identity || "").toLowerCase()
        var service = (activePlayer.service || "").toLowerCase()
        return app.indexOf("spotify") !== -1
            || identity.indexOf("spotify") !== -1
            || service.indexOf("spotify") !== -1
    }

    spacing: 5
    visible: root.activePlayer !== null && root.isSpotify

    Icon {
        source: root.activePlayer?.isPlaying != MprisPlaybackState.Playing ? Quickshell.iconPath("media-playback-start-symbolic") : Quickshell.iconPath("media-playback-pause-symbolic")
    }

    Text {
        color: Appearance.colors.on_surface
        font.family: Appearance.font.sans
        font.pixelSize: Appearance.fontSize.normal
        font.weight: Font.Medium

        text: {
            if (root.activePlayer === null) {
                return "No media playing";
            }

            var artist = root.activePlayer.trackArtist || "Unknown Artist";
            var title = root.activePlayer.trackTitle || "Unknown Track";

            return artist + " - " + title;
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button == Qt.LeftButton && root.activePlayer) {
                    activePlayer.togglePlaying()
                }
                if (mouse.button == Qt.RightButton) {
                    Dashboard.toggle("mpris")
                }
            }
        }
    }
}
