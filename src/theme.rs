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

/*
 * how much of the scrim's color covers the windows behind a surface. on
 * its own it let a window's text read through; umbriel blurs behind the
 * surface too (a layer rule on yohaku-surface), which does that job
 */
pub const SCRIM_OPACITY: f32 = 0.60;

// names and titles
pub const SANS: &str = "Outfit";
// readouts: times, numbers, labels
pub const MONO: &str = "Iosevka";

// how surfaces and the poster come and go, in seconds and pixels
pub mod timing {
    // coming in, and the beat the content waits behind the scrim
    pub const IN: f32 = 0.26;
    pub const BEAT: f32 = 0.07;
    // going out, quicker than coming in
    pub const OUT: f32 = 0.16;
    // how far below its place the content starts, and ends up when it leaves
    pub const SHIFT: f32 = 12.0;
    // how long a toast stays, unless it is critical or under the pointer
    pub const TOAST: f32 = 4.0;
}

// the 12-column grid every surface snaps to, and the spacing steps between things
pub mod grid {
    pub const COLUMNS: u32 = 12;
    pub const MARGIN: f32 = 72.0;
    pub const GUTTER: f32 = 24.0;

    // the width of `columns` columns and the gutters between them, on a screen this wide
    pub fn span(columns: u32, screen_width: f32) -> f32 {
        let free = screen_width - 2.0 * MARGIN - (COLUMNS - 1) as f32 * GUTTER;
        let column = free / COLUMNS as f32;

        columns as f32 * column + columns.saturating_sub(1) as f32 * GUTTER
    }
}

pub mod space {
    pub const SM: f32 = 8.0;
    pub const MD: f32 = 16.0;
    pub const LG: f32 = 32.0;
}

// the type sizes surfaces pick from, three at most per surface
pub mod size {
    pub const LG: f32 = 88.0;
    pub const POSTER: f32 = 260.0;
    pub const MD: f32 = 18.0;
    pub const SM: f32 = 12.0;
}

// a notification toast, top right under the bar
pub mod toast {
    // grid columns wide
    pub const COLUMNS: u32 = 3;
    // the body is cut after this many lines
    pub const BODY_LINES: usize = 2;

    /*
     * the scrim comes in from the screen's corner instead of sitting behind
     * the text: full strength over the text and off the edges, fading out
     * to the left and below. this is its fade, as a blur in pixels
     */
    pub const WASH: f32 = 120.0;

    /*
     * the wash's edge sits this far past the text, so the text stays on the
     * dense part: a blur spans two deviations, and 1.3 of them in is ~90%
     */
    pub const fn inset() -> f32 {
        WASH * 0.65
    }

    // how far past its edge the wash still shows; it is gone by three deviations
    pub const fn fade() -> f32 {
        WASH * 1.5
    }
}

// a region screenshot: the frozen frame, dimmed outside the box being drawn
pub mod shot {
    // how much of the scrim covers the frame outside the box
    pub const DIM: f32 = 0.45;
    // the box's outline
    pub const BORDER: f32 = 1.0;
    // a box smaller than this either way is a stray click, not a region
    pub const MIN: f32 = 4.0;
}

// the launcher and the surfaces shaped like it: a large query over a fixed list
pub mod list {
    // rows the list reserves room for, so the query above it never moves
    pub const ROWS: f32 = 10.0;
    // the query keeps its last characters when it outgrows the column
    pub const QUERY_CHARS: usize = 12;
    // a row's right-hand description is cut to this many characters
    pub const DESCRIPTION_CHARS: usize = 24;
    // the caret is a still, thin bar of this share of the query's size
    pub const CARET_WIDTH: f32 = 0.08;
    pub const CARET_HEIGHT: f32 = 0.9;
}

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

// yohaku's own config, next to its code; nothing is read from another shell's folder
pub fn config_folder() -> PathBuf {
    let base = env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))
        .unwrap_or_else(|| PathBuf::from("/tmp"));

    base.join("amane/yohaku")
}

// where the scheme lives; the wallpaper writes it, the theme follows it
pub fn scheme_path() -> PathBuf {
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
    pub scrim: Color,
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
        scrim: scheme.get("scrim"),
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
