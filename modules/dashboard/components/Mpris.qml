pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

import qs.components
import qs.config
import qs.services

Item {
    id: root

    readonly property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players?.values.filter(player => player.identity === "Spotify")[0] ?? null : null
    readonly property string artUrl: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""

    Component.onCompleted: ArtCache.resolve(root.artUrl)
    onArtUrlChanged: ArtCache.resolve(root.artUrl)
    readonly property real trackLength: root.activePlayer?.length ?? 0
    readonly property bool showProgress: root.activePlayer !== null && root.trackLength > 0

    // position does not emit change notifications continuously by design
    // (see MprisPlayer.position docs); reading it is always current and
    // cheap, so drive the bindings by emitting positionChanged() manually
    // while playing. The extra emit on state change keeps the displayed
    // position exact at the pause/resume moment.
    Timer {
        interval: 1000
        running: root.activePlayer?.isPlaying ?? false
        repeat: true
        onTriggered: root.activePlayer?.positionChanged()
    }

    Connections {
        target: root.activePlayer

        function onIsPlayingChanged() {
            root.activePlayer?.positionChanged();
        }
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

            Rectangle {
                anchors.fill: parent
                visible: artImage.status !== Image.Ready
                color: Appearance.colors.surface_container_high

                Item {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    visible: artImage.status === Image.Loading

                    Canvas {
                        id: spinner
                        anchors.fill: parent

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.lineWidth = 3;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = Appearance.colors.primary;
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, width / 2 - 6, 0, Math.PI * 1.5);
                            ctx.stroke();
                        }
                        Component.onCompleted: requestPaint()

                        RotationAnimation on rotation {
                            running: artImage.status === Image.Loading
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 64
                    visible: artImage.status !== Image.Loading
                    source: Quickshell.iconPath("audio-x-generic-symbolic")
                }
            }

            Image {
                id: artImage
                anchors.fill: parent
                source: ArtCache.resolvedUrl
                fillMode: Image.PreserveAspectCrop
                retainWhileLoading: true
                asynchronous: true
                sourceSize: Qt.size(Math.round(width * Screen.devicePixelRatio), Math.round(height * Screen.devicePixelRatio))
                opacity: status === Image.Ready ? 1 : 0

                onStatusChanged: {
                    if (status === Image.Error)
                        ArtCache.notifyImageError(source.toString());
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
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
                    progress: root.trackLength > 0 ? Math.min(1, (root.activePlayer?.position ?? 0) / root.trackLength) : 0
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: root.formatTime(root.activePlayer?.position ?? 0)
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
                    padding: Appearance.padding.smaller
                    verticalPadding: Appearance.padding.smaller
                    enabled: root.activePlayer !== null
                    contentItem: Icon {
                        source: Quickshell.iconPath(root.activePlayer?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                        opacity: enabled ? 1 : 0.3
                    }
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
