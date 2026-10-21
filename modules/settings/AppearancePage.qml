pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Theme pane for the console band: scheme source (default palette, or
// matugen colors taken from a wallpaper) plus the wallpaper picker. awww
// draws the background; this only chooses the file and reports what the
// scheme became.
//
// Fixed height, like DashboardPane: the band sizes to its content, so a
// gallery pane has to cap itself rather than grow the band to fit.
Item {
    id: root

    implicitHeight: 400

    // Six columns across the band, thumbnails 16:9 to match the wallpaper
    // aspect most previews use.
    readonly property int columns: 6
    readonly property int slot: Math.floor(width / root.columns)
    readonly property int thumbWidth: root.slot - Appearance.spacing.small
    readonly property int thumbHeight: Math.round(root.thumbWidth * 9 / 16)

    Component.onCompleted: Theme.refreshWallpapers()

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledButton {
                text: "Default"
                checked: !Theme.wallpaperColors
                onClicked: Theme.useDefault()
            }

            StyledButton {
                text: Theme.generating ? "Generating" : "Wallpaper Colors"
                checkable: true
                checked: Theme.wallpaperColors
                enabled: Theme.matugenPresent && Appearance.wallpaper !== "" && !Theme.generating
                onClicked: Theme.useWallpaperColors()
            }

            StyledText {
                text: Theme.status
                color: Appearance.colors.on_surface_variant
                font.pixelSize: Appearance.fontSize.xs
                elide: Text.ElideRight
                Layout.maximumWidth: 360
            }

            Rule {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            HudLabel {
                label: `${Theme.wallpapers.length} wallpapers`
            }
        }

        GridView {
            id: wallGrid

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 0

            // Spacing lives in the cell: GridView has no gap property.
            cellWidth: root.slot
            cellHeight: root.thumbHeight + Appearance.spacing.small
            model: Theme.wallpapers

            delegate: Item {
                id: cell

                required property string modelData

                readonly property bool current: modelData === Appearance.wallpaper

                width: wallGrid.cellWidth
                height: wallGrid.cellHeight

                Rectangle {
                    width: root.thumbWidth
                    height: root.thumbHeight
                    color: Appearance.colors.surface_container
                    border.width: cell.current ? 2 : 1
                    border.color: cell.current ? Appearance.colors.primary : Appearance.colors.outline_variant

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: "file://" + cell.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(320, 180)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Theme.setWallpaper(cell.modelData)
                    }
                }
            }
        }
    }
}
