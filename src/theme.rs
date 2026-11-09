use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;

use amane::{Color, Service};

/*
 * every design value lives here, widgets never carry their own colors,
 * sizes or durations; the numbers are the ones settled in the
 * design prototype
 */

// names and titles
pub const SANS: &str = "Outfit";
// readouts: times, numbers, labels
pub const MONO: &str = "Iosevka";

pub mod bar {
    pub const HEIGHT: f32 = 44.0;
    // the workspace line along the top edge
    pub const LINE: f32 = 2.0;
    pub const LINE_GAP: f32 = 5.0;
    // from the screen edge to the first and last item
    pub const EDGE: f32 = 20.0;
    // between groups, and around the rules that split them
    pub const GROUP_GAP: f32 = 20.0;
    // between an icon and its text, and between the stats rings
    pub const ITEM_GAP: f32 = 6.0;
    pub const TEXT: f32 = 14.0;
    pub const TAG: f32 = 12.0;
    pub const RULE_HEIGHT: f32 = 16.0;
    pub const RULE_WIDTH: f32 = 1.0;
    // symbolic icons next to text
    pub const ICON: f32 = 16.0;
    // the SYS rings
    pub const RING: f32 = 14.0;
    pub const RING_STROKE: f32 = 2.0;
    // the PWR battery: a row of segments, lit in proportion to the charge
    pub const BATTERY_SEGMENTS: usize = 8;
    pub const BATTERY_WIDTH: f32 = 52.0;
    pub const BATTERY_HEIGHT: f32 = 8.0;
    pub const BATTERY_GAP: f32 = 2.0;
    // "artist - title" is cut to this many characters, so a long track can't crowd the clock
    pub const MEDIA_CHARS: usize = 48;
}

/*
 * the scheme matugen writes into yohaku's state, one `role=#rrggbb` per line;
 * until the first wallpaper is set the default scheme is used
 */
pub struct Scheme {
    colors: HashMap<String, Color>,
}

// the default scheme, also the fallback for any role a file leaves out
const DEFAULT: [(&str, &str); 15] = [
    ("background", "#111318"),
    ("error", "#ffb4ab"),
    ("on_surface", "#e2e2e9"),
    ("on_surface_variant", "#c4c6d0"),
    ("outline", "#8e9099"),
    ("outline_variant", "#44474e"),
    ("primary", "#a9c7ff"),
    ("primary_container", "#274777"),
    ("on_primary", "#09305f"),
    ("scrim", "#000000"),
    ("surface", "#111318"),
    ("surface_container", "#1d2024"),
    ("surface_container_high", "#282a2f"),
    ("tertiary", "#dcbce1"),
    ("tertiary_container", "#563e5c"),
];

impl Service for Scheme {
    fn new() -> Self {
        Self { colors: load() }
    }

    fn listen() {
        let path = scheme_path();

        // the folder has to exist before it can be watched
        if let Some(folder) = path.parent() {
            let _ = fs::create_dir_all(folder);
        }

        for _ in amane::watch_file(&path.to_string_lossy()) {
            Self::write().colors = load();
        }
    }
}

impl Scheme {
    fn get(&self, role: &str) -> Color {
        self.colors.get(role).copied().unwrap_or(Color::BLACK)
    }
}

// state that yohaku writes and reads back, never anything of another shell's
pub fn state_folder() -> PathBuf {
    let base = env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/state")))
        .unwrap_or_else(|| PathBuf::from("/tmp"));

    base.join("yohaku")
}

fn scheme_path() -> PathBuf {
    state_folder().join("scheme")
}

fn load() -> HashMap<String, Color> {
    let mut colors: HashMap<String, Color> = DEFAULT
        .iter()
        .map(|(role, hex)| (role.to_string(), Color::from(*hex)))
        .collect();

    let text = fs::read_to_string(scheme_path()).unwrap_or_default();

    for line in text.lines() {
        let Some((role, hex)) = line.split_once('=') else {
            continue;
        };

        let hex = hex.trim();

        // a half-written line keeps the old color instead of turning magenta
        if !is_hex(hex) {
            continue;
        }

        colors.insert(role.trim().to_string(), Color::from(hex));
    }

    colors
}

fn is_hex(text: &str) -> bool {
    let digits = text.trim_start_matches('#');

    matches!(digits.len(), 6 | 8) && digits.chars().all(|c| c.is_ascii_hexdigit())
}

// the roles widgets use, read once per frame
#[derive(Clone, Copy)]
pub struct Theme {
    pub surface: Color,
    pub on_surface: Color,
    pub on_surface_variant: Color,
    pub outline: Color,
    pub outline_variant: Color,
    pub primary: Color,
    pub surface_container_high: Color,
    pub error: Color,
}

pub fn current() -> Theme {
    let scheme = Scheme::read();

    Theme {
        surface: scheme.get("surface"),
        on_surface: scheme.get("on_surface"),
        on_surface_variant: scheme.get("on_surface_variant"),
        outline: scheme.get("outline"),
        outline_variant: scheme.get("outline_variant"),
        primary: scheme.get("primary"),
        surface_container_high: scheme.get("surface_container_high"),
        error: scheme.get("error"),
    }
}

// the same color at a fraction of its opacity, for the workspace line's quiet tones
pub fn faded(color: Color, opacity: f32) -> Color {
    let alpha = (color.alpha() as f32 * opacity.clamp(0.0, 1.0)).round() as u8;

    Color::rgba(color.red(), color.green(), color.blue(), alpha)
}
