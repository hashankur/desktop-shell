pragma Singleton

import Quickshell
import Quickshell.Io

import "palette.js" as Palette

// File-backed tokens. JsonAdapter maps each declared property to a JSON
// key, so the values below are the fallback: with no appearance.json every
// token reads as cobalt + paper, exactly as before. Loading a file
// overrides only the keys it contains; Theme.qml writes it.
//
// JsonObject alone cannot read files (it is a bare QObject), hence the
// FileView wrapper. The aliases keep the public surface as
// Appearance.colors / .rounding / ... so the 31 files that read tokens
// are untouched.
FileView {
    id: root

    // Private state (never written by the shell): the scheme in force.
    path: Quickshell.env("HOME") + "/.config/quickshell/appearance.json"
    watchChanges: true
    // Missing on a fresh install; the declared defaults below are the
    // answer, so the load failure is expected rather than worth logging.
    printErrors: false
    onFileChanged: root.reload()

    JsonAdapter {
        id: adapter
        property Colors colors: Colors {}
        property Rounding rounding: Rounding {}
        property Spacing spacing: Spacing {}
        property Padding padding: Padding {}
        property FontFamily font: FontFamily {}
        property FontSize fontSize: FontSize {}
        property Tracking tracking: Tracking {}
        property Anim anim: Anim {}
        property Transparency transparency: Transparency {}
        // Theme state rides in the same file so it survives a restart.
        property string themeMode: "default"
        property string wallpaper: ""
    }

    // True once the theme file has been read, or found absent. Theme.qml
    // gates its writes on this: persisting before the load lands would
    // serialize the declared defaults over the user's saved scheme.
    property bool _settled: false
    onLoaded: root._settled = true
    onLoadFailed: (e) => root._settled = true
    readonly property alias settled: root._settled

    readonly property alias colors: adapter.colors
    readonly property alias rounding: adapter.rounding
    readonly property alias spacing: adapter.spacing
    readonly property alias padding: adapter.padding
    readonly property alias font: adapter.font
    readonly property alias fontSize: adapter.fontSize
    readonly property alias tracking: adapter.tracking
    readonly property alias anim: adapter.anim
    readonly property alias transparency: adapter.transparency
    // Writable: Theme.qml flips these. The colors alias stays readonly so
    // call sites cannot repaint the scheme by accident; Theme writes them
    // through Appearance.setColors().
    property alias themeMode: adapter.themeMode
    property alias wallpaper: adapter.wallpaper

    // Write-through for Theme.qml. Keys are filtered against the palette
    // because assigning an undeclared key to a JsonObject is not a no-op.
    function setColors(map) {
        const target = adapter.colors;
        for (const key in Palette.cobalt.colors) {
            if (map[key] !== undefined)
                target[key] = map[key];
        }
    }

    // Cobalt + paper HUD scheme: deep blue ground, paper-white text,
    // signal orange accent, alarm red. Token names stay Material-3 so
    // existing call sites keep working; `primary_container` reads as an
    // inverted paper chip (text goes through `on_primary_container`).
    // Values live in palette.js so Theme can restore them.
    component Colors: JsonObject {
        property string background: Palette.cobalt.colors.background
        property string error: Palette.cobalt.colors.error
        property string error_container: Palette.cobalt.colors.error_container
        property string inverse_on_surface: Palette.cobalt.colors.inverse_on_surface
        property string inverse_primary: Palette.cobalt.colors.inverse_primary
        property string inverse_surface: Palette.cobalt.colors.inverse_surface
        property string on_background: Palette.cobalt.colors.on_background
        property string on_error: Palette.cobalt.colors.on_error
        property string on_error_container: Palette.cobalt.colors.on_error_container
        property string on_primary: Palette.cobalt.colors.on_primary
        property string on_primary_container: Palette.cobalt.colors.on_primary_container
        property string on_primary_fixed: Palette.cobalt.colors.on_primary_fixed
        property string on_primary_fixed_variant: Palette.cobalt.colors.on_primary_fixed_variant
        property string on_secondary: Palette.cobalt.colors.on_secondary
        property string on_secondary_container: Palette.cobalt.colors.on_secondary_container
        property string on_secondary_fixed: Palette.cobalt.colors.on_secondary_fixed
        property string on_secondary_fixed_variant: Palette.cobalt.colors.on_secondary_fixed_variant
        property string on_surface: Palette.cobalt.colors.on_surface
        property string on_surface_variant: Palette.cobalt.colors.on_surface_variant
        property string on_tertiary: Palette.cobalt.colors.on_tertiary
        property string on_tertiary_container: Palette.cobalt.colors.on_tertiary_container
        property string on_tertiary_fixed: Palette.cobalt.colors.on_tertiary_fixed
        property string on_tertiary_fixed_variant: Palette.cobalt.colors.on_tertiary_fixed_variant
        property string outline: Palette.cobalt.colors.outline
        property string outline_variant: Palette.cobalt.colors.outline_variant
        property string primary: Palette.cobalt.colors.primary
        property string primary_container: Palette.cobalt.colors.primary_container
        property string primary_fixed: Palette.cobalt.colors.primary_fixed
        property string primary_fixed_dim: Palette.cobalt.colors.primary_fixed_dim
        property string scrim: Palette.cobalt.colors.scrim
        property string secondary: Palette.cobalt.colors.secondary
        property string secondary_container: Palette.cobalt.colors.secondary_container
        property string secondary_fixed: Palette.cobalt.colors.secondary_fixed
        property string secondary_fixed_dim: Palette.cobalt.colors.secondary_fixed_dim
        property string shadow: Palette.cobalt.colors.shadow
        property string source_color: Palette.cobalt.colors.source_color
        property string surface: Palette.cobalt.colors.surface
        property string surface_bright: Palette.cobalt.colors.surface_bright
        property string surface_container: Palette.cobalt.colors.surface_container
        property string surface_container_high: Palette.cobalt.colors.surface_container_high
        property string surface_container_highest: Palette.cobalt.colors.surface_container_highest
        property string surface_container_low: Palette.cobalt.colors.surface_container_low
        property string surface_container_lowest: Palette.cobalt.colors.surface_container_lowest
        property string surface_dim: Palette.cobalt.colors.surface_dim
        property string surface_tint: Palette.cobalt.colors.surface_tint
        property string surface_variant: Palette.cobalt.colors.surface_variant
        property string tertiary: Palette.cobalt.colors.tertiary
        property string tertiary_container: Palette.cobalt.colors.tertiary_container
        property string tertiary_fixed: Palette.cobalt.colors.tertiary_fixed
        property string tertiary_fixed_dim: Palette.cobalt.colors.tertiary_fixed_dim
    }

    // HUD geometry: sharp corners everywhere. `full` stays large so true
    // circles (rings, dots) survive; pills are being cut down to rects
    // module by module, so never use `full` for a new rounded rect.
    component Rounding: JsonObject {
        property real scale: 1
        property int small: 0
        property int normal: 0
        property int large: 0
        property int full: 1000 * scale
    }

    component Spacing: JsonObject {
        property real scale: 1
        property int small: 7 * scale
        property int smaller: 10 * scale
        property int normal: 12 * scale
        property int larger: 15 * scale
        property int large: 20 * scale
    }

    component Padding: JsonObject {
        property real scale: 1
        property int small: 5 * scale
        property int smaller: 7 * scale
        property int normal: 10 * scale
        property int larger: 12 * scale
        property int large: 15 * scale
    }

    component FontFamily: JsonObject {
        property string sans: "Outfit"
        property string mono: "Iosevka"
    }

    component FontSize: JsonObject {
        property real scale: 1
        property int xs: 12 * scale
        property int sm: 14 * scale
        property int base: 16 * scale
        property int lg: 18 * scale
        property int xl: 20 * scale
        property int xxl: 24 * scale
        property int xxxl: 30 * scale
    }

    // font.letterSpacing values, in px. `micro` is for uppercase
    // letterspaced HUD labels, `label` for section tags.
    component Tracking: JsonObject {
        property real micro: 1.4
        property real label: 0.8
        property real none: 0
    }

    component FontStuff: JsonObject {
        property FontFamily family: FontFamily {}
        property FontSize size: FontSize {}
    }

    component AnimCurves: JsonObject {
        property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        property list<real> expressiveEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    }

    component AnimDurations: JsonObject {
        property real scale: 1
        property int small: 200 * scale
        property int medium: 300 * scale
        property int normal: 400 * scale
        property int large: 600 * scale
        property int extraLarge: 1000 * scale
        property int expressiveFastSpatial: 350 * scale
        property int expressiveDefaultSpatial: 500 * scale
        property int expressiveEffects: 200 * scale
    }

    component Anim: JsonObject {
        property AnimCurves curves: AnimCurves {}
        property AnimDurations durations: AnimDurations {}
    }

    component Transparency: JsonObject {
        property bool enabled: false
        property real base: 0.85
        property real layers: 0.4
    }
}
