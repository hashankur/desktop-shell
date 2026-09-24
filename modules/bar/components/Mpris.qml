import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

Row {
    id: root

    readonly property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players?.values.filter(player => player.identity === "Spotify")[0] ?? null : null
    readonly property bool isPlaying: root.activePlayer?.isPlaying ?? false
    spacing: 5
    visible: root.activePlayer !== null

    Icon {
        source: root.isPlaying ? Quickshell.iconPath("media-playback-pause-symbolic") : Quickshell.iconPath("media-playback-start-symbolic")
    }

    StyledText {
        font.pixelSize: Appearance.fontSize.sm

        text: {
            if (root.activePlayer === null) {
                return "No media playing";
            }

            var artist = root.activePlayer?.trackArtist || "Unknown Artist";
            var title = root.activePlayer?.trackTitle || "Unknown Track";

            return artist + " - " + title;
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button == Qt.LeftButton && root.activePlayer) {
                    root.activePlayer.togglePlaying();
                }
                if (mouse.button == Qt.RightButton) {
                    Dashboard.toggle("mpris");
                }
            }
        }
    }
}
