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
    // Room the bar leaves for this chip; the title elides to fit so it can
    // never run over the divider to its left.
    property real maxWidth: Infinity
    spacing: 5
    visible: root.activePlayer !== null

    Icon {
        id: stateIcon
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 14
        source: root.isPlaying ? Quickshell.iconPath("media-playback-pause-symbolic") : Quickshell.iconPath("media-playback-start-symbolic")
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: font.pixelSize / 10
        mono: true
        font.pixelSize: Appearance.fontSize.sm
        elide: Text.ElideRight
        width: Math.max(0, Math.min(implicitWidth, root.maxWidth - stateIcon.width - root.spacing))

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
