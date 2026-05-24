pragma Singleton

import Quickshell.Io

JsonObject {
    property Colors colors: Colors {}
    property Rounding rounding: Rounding {}
    property Spacing spacing: Spacing {}
    property Padding padding: Padding {}
    property FontFamily font: FontFamily {}
    property FontSize fontSize: FontSize {}
    property Anim anim: Anim {}
    property Transparency transparency: Transparency {}

    component Colors: JsonObject {
        property string background: "#0e1415"
        property string error: "#ffb4ab"
        property string error_container: "#93000a"
        property string inverse_on_surface: "#2b3132"
        property string inverse_primary: "#006972"
        property string inverse_surface: "#dee4e4"
        property string on_background: "#dee4e4"
        property string on_error: "#690005"
        property string on_error_container: "#ffdad6"
        property string on_primary: "#00363b"
        property string on_primary_container: "#9df0fa"
        property string on_primary_fixed: "#001f23"
        property string on_primary_fixed_variant: "#004f56"
        property string on_secondary: "#1c3437"
        property string on_secondary_container: "#cde7eb"
        property string on_secondary_fixed: "#051f22"
        property string on_secondary_fixed_variant: "#324b4e"
        property string on_surface: "#dee4e4"
        property string on_surface_variant: "#bec8c9"
        property string on_tertiary: "#22304c"
        property string on_tertiary_container: "#d8e2ff"
        property string on_tertiary_fixed: "#0c1b36"
        property string on_tertiary_fixed_variant: "#394764"
        property string outline: "#899294"
        property string outline_variant: "#3f484a"
        property string primary: "#81d3de"
        property string primary_container: "#004f56"
        property string primary_fixed: "#9df0fa"
        property string primary_fixed_dim: "#81d3de"
        property string scrim: "#000000"
        property string secondary: "#b1cbcf"
        property string secondary_container: "#324b4e"
        property string secondary_fixed: "#cde7eb"
        property string secondary_fixed_dim: "#b1cbcf"
        property string shadow: "#000000"
        property string source_color: "#4f6669"
        property string surface: "#0e1415"
        property string surface_bright: "#343a3b"
        property string surface_container: "#1a2121"
        property string surface_container_high: "#252b2c"
        property string surface_container_highest: "#303637"
        property string surface_container_low: "#171d1d"
        property string surface_container_lowest: "#090f10"
        property string surface_dim: "#0e1415"
        property string surface_tint: "#81d3de"
        property string surface_variant: "#3f484a"
        property string tertiary: "#b8c6ea"
        property string tertiary_container: "#394764"
        property string tertiary_fixed: "#d8e2ff"
        property string tertiary_fixed_dim: "#b8c6ea"
    }

    component Rounding: JsonObject {
        property real scale: 1
        property int small: 5 * scale
        property int normal: 10 * scale
        property int large: 20 * scale
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
        property string sans: "Satoshi Variable"
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
