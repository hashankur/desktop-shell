.pragma library

// The default scheme, kept out of Appearance.qml so it stays the single
// source of truth for the cobalt palette: Appearance uses it as the
// JsonAdapter's declared defaults (what you get before any file is read),
// and Theme.qml re-applies it to go back to the default scheme.
//
// Appearance.colors stays the public API; every call site reads through it.
var cobalt = {
    colors: {
        background: "#0d2557",
        error: "#ff6459",
        error_container: "#6b1410",
        inverse_on_surface: "#0d2557",
        inverse_primary: "#ff5e1f",
        inverse_surface: "#edeff5",
        on_background: "#edeff5",
        on_error: "#3b0704",
        on_error_container: "#ffdad6",
        on_primary: "#2b0a00",
        on_primary_container: "#0d2557",
        on_primary_fixed: "#2b0a00",
        on_primary_fixed_variant: "#6b2400",
        on_secondary: "#0d2557",
        on_secondary_container: "#c7d6f5",
        on_secondary_fixed: "#04122e",
        on_secondary_fixed_variant: "#1a3877",
        on_surface: "#edeff5",
        on_surface_variant: "#9cafd8",
        on_tertiary: "#04241c",
        on_tertiary_container: "#9df5e0",
        on_tertiary_fixed: "#00201a",
        on_tertiary_fixed_variant: "#004b3c",
        outline: "#7c93c7",
        outline_variant: "#2a4786",
        primary: "#ff5e1f",
        primary_container: "#edeff5",
        primary_fixed: "#ff8a52",
        primary_fixed_dim: "#ff5e1f",
        scrim: "#000000",
        secondary: "#edeff5",
        secondary_container: "#1a3877",
        secondary_fixed: "#edeff5",
        secondary_fixed_dim: "#c7d6f5",
        shadow: "#000000",
        source_color: "#ff5e1f",
        surface: "#0d2557",
        surface_bright: "#2c55a8",
        surface_container: "#12306b",
        surface_container_high: "#194088",
        surface_container_highest: "#1f4a9c",
        surface_container_low: "#0a1d45",
        surface_container_lowest: "#06122e",
        surface_dim: "#0d2557",
        surface_tint: "#ff5e1f",
        surface_variant: "#2a4786",
        tertiary: "#5ad3b6",
        tertiary_container: "#0e4b3d",
        tertiary_fixed: "#5ad3b6",
        tertiary_fixed_dim: "#3dbfa3"
    }
};
