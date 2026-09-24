pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

import qs.components
import qs.config

Item {
    id: root

    readonly property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players?.values.filter(player => player.identity === "Spotify")[0] ?? null : null
    readonly property string artUrl: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
    readonly property real trackLength: root.activePlayer?.length ?? 0
    readonly property bool showProgress: root.activePlayer !== null && root.trackLength > 0

    // The player's position property may not tick continuously; resync on
    // player notifications and advance locally while playing so the bar moves.
    property real _basePosition: 0
    property real _baseStamp: 0
    property int _tick: 0

    function _syncPosition() {
        root._basePosition = root.activePlayer ? root.activePlayer.position : 0;
        root._baseStamp = Date.now();
    }

    readonly property real position: {
        var p = root._basePosition;
        if (root.activePlayer && root.activePlayer.isPlaying)
            p += (Date.now() - root._baseStamp) / 1000;
        void root._tick;
        return Math.min(p, root.trackLength);
    }

    onActivePlayerChanged: root._syncPosition()

    Connections {
        target: root.activePlayer

        function onPositionChanged() {
            root._syncPosition();
        }

        function onTrackChanged() {
            root._syncPosition();
        }

        function onIsPlayingChanged() {
            root._syncPosition();
        }

        function onLengthChanged() {
            root._syncPosition();
        }
    }

    Timer {
        interval: 1000
        running: root.activePlayer?.isPlaying ?? false
        repeat: true
        onTriggered: root._tick++
    }

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        if (h > 0)
            return `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
        return `${m}:${String(sec).padStart(2, "0")}`;
    }

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.large

        ClippingRectangle {
            Layout.preferredWidth: 420
            Layout.preferredHeight: 420
            Layout.alignment: Qt.AlignVCenter
            radius: Appearance.rounding.small
            color: Appearance.colors.surface_container

            Image {
                anchors.fill: parent
                visible: root.artUrl !== ""
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                retainWhileLoading: true
                asynchronous: true
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
            Layout.margins: Appearance.spacing.large
            spacing: Appearance.spacing.normal

            StyledText {
                text: root.activePlayer ? (root.activePlayer?.trackTitle || "Unknown track") : "No media playing"
                font.pixelSize: Appearance.fontSize.xxxl
                font.weight: Font.Black
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            StyledText {
                text: root.activePlayer ? (root.activePlayer?.trackArtist || "Unknown artist") : "Start playback to see album art and controls here."
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.xl
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            StyledText {
                text: root.activePlayer?.trackAlbum ?? ""
                visible: text.length > 0
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.lg
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
            }

            ColumnLayout {
                visible: root.showProgress
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                ProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    progress: root.trackLength > 0 ? Math.min(1, root.position / root.trackLength) : 0
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: root.formatTime(root.position)
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.xs
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: root.formatTime(root.trackLength)
                        color: Appearance.colors.on_surface_variant
                        font.pixelSize: Appearance.fontSize.xs
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Appearance.spacing.normal

                StyledButton {
                    ghost: true
                    padding: Appearance.padding.smaller
                    verticalPadding: Appearance.padding.smaller
                    enabled: (root.activePlayer?.canGoPrevious ?? false) && (root.activePlayer?.canControl ?? true)
                    contentItem: Icon {
                        source: Quickshell.iconPath("media-skip-backward-symbolic")
                        opacity: enabled ? 1 : 0.3
                    }
                    onClicked: root.activePlayer?.previous()
                }

                StyledButton {
                    text: root.activePlayer && root.activePlayer.isPlaying ? "Pause" : "Play"
                    enabled: root.activePlayer !== null
                    onClicked: root.activePlayer?.togglePlaying()
                }

                StyledButton {
                    ghost: true
                    padding: Appearance.padding.smaller
                    verticalPadding: Appearance.padding.smaller
                    enabled: (root.activePlayer?.canGoNext ?? false) && (root.activePlayer?.canControl ?? true)
                    contentItem: Icon {
                        source: Quickshell.iconPath("media-skip-forward-symbolic")
                        opacity: enabled ? 1 : 0.3
                    }
                    onClicked: root.activePlayer?.next()
                }
            }
        }
    }
}
