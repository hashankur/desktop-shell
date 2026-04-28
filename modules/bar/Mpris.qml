import QtQuick
import Quickshell.Services.Mpris

import qs.config

Text {
    color: Appearance.colors.on_surface
    font.family: Appearance.font.sans
    font.pixelSize: Appearance.fontSize.normal
    font.weight: Font.Medium

    // Get the active/current player from the values array
    readonly property var activePlayer: Mpris.players.values && Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    text: {
        if (activePlayer === null) {
            return "No media playing";
        }

        var artist = activePlayer.trackArtist || "Unknown Artist";
        var title = activePlayer.trackTitle || "Unknown Track";

        return artist + " - " + title;
    }
}
