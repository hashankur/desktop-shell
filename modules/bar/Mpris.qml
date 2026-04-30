import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

import qs.components
import qs.config

Row {
    // Get the active/current player from the values array
    readonly property var activePlayer: Mpris.players.values && Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    spacing: 10
    visible: activePlayer !== null

    Icon {
        source: activePlayer?.isPlaying != MprisPlaybackState.Playing ? Quickshell.iconPath("media-playback-start-symbolic") : Quickshell.iconPath("media-playback-pause-symbolic")
    }

    Text {
        color: Appearance.colors.on_surface
        font.family: Appearance.font.sans
        font.pixelSize: Appearance.fontSize.normal
        font.weight: Font.Medium

        text: {
            if (activePlayer === null) {
                return "No media playing";
            }

            var artist = activePlayer.trackArtist || "Unknown Artist";
            var title = activePlayer.trackTitle || "Unknown Track";

            return artist + " - " + title;
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: activePlayer.togglePlaying()
        }
    }
}
