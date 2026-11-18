use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;

use amane::{Color, Service, Weight};

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

// how surfaces come and go, in seconds and pixels
pub mod timing {
    // coming in, and the beat the content waits behind the scrim
    pub const IN: f32 = 0.26;
    pub const BEAT: f32 = 0.07;
    // going out, quicker than coming in
    pub const OUT: f32 = 0.16;
    // how far below its place the content starts, and ends up when it leaves
    pub const SHIFT: f32 = 12.0;
    // a bar item easing into and out of its hovered colour, and unfolding its details
    pub const HOVER: f32 = 0.18;
    // how long a toast stays after it comes, or after the pointer leaves it, unless it is critical
    pub const TOAST: f32 = 5.0;
    // how long the osd stays after the last change
    pub const OSD: f32 = 1.5;
    // how long after the shell starts a level change is taken as settling, not a key
    pub const OSD_SETTLE: f32 = 1.0;
}

// the volume and brightness readout, bottom right; it sits on the same wash as a toast
pub mod osd {
    pub const WIDTH: f32 = 220.0;
    // the level line under the label, and the gap above it
    pub const TRACK: f32 = 1.0;
    pub const TRACK_GAP: f32 = 8.0;
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
    pub const XS: f32 = 4.0;
    pub const SM: f32 = 8.0;
    pub const MD: f32 = 16.0;
    pub const LG: f32 = 32.0;
}

// the type sizes surfaces pick from, three at most per surface
pub mod size {
    pub const LG: f32 = 88.0;
    pub const MD: f32 = 18.0;
    pub const SM: f32 = 12.0;
}

// the lock screen's clock
pub mod lock {
    pub const TIME: f32 = 230.0;
    // the am/pm after the time
    pub const PERIOD: f32 = 30.0;
    pub const DATE: f32 = 22.0;

    // the fonts' vertical metrics per em (outfit, iosevka), read from their tables, to line
    // the lock clock up by its ink: a text box runs from its ascent to its descent
    const SANS_ASCENT: f32 = 1.0;
    const SANS_DESCENT: f32 = 0.26;
    const SANS_CAP: f32 = 0.676;
    const MONO_DESCENT: f32 = 0.285;

    // the empty room above the time's digits, which the clock is pulled up by
    pub fn above_digits() -> f32 {
        (SANS_ASCENT - SANS_CAP) * TIME
    }

    // how far the am/pm rises: aligned by their bottom edges, its baseline sits below the time's
    // because the big text has far more room under its baseline
    pub fn period_lift() -> f32 {
        SANS_DESCENT * TIME - MONO_DESCENT * PERIOD
    }

    // how far the date rises, so it is measured from the time's baseline, not its bottom edge
    pub fn date_rise() -> f32 {
        SANS_DESCENT * TIME
    }
}

// a notification toast, top right under the bar
pub mod toast {
    // grid columns wide
    pub const COLUMNS: u32 = 3;
    // the body is cut after this many lines
    pub const BODY_LINES: usize = 2;

    // small text over a window needs more than the surfaces' scrim, so the wash is denser
    pub const SCRIM_OPACITY: f32 = 0.80;
    // a weight up from regular, so thin strokes hold over a window
    pub const WEIGHT: super::Weight = super::Weight::Medium;
    pub const SUMMARY_WEIGHT: super::Weight = super::Weight::SemiBold;
    // the body is a sentence, so it is set in the sans, a step above the small mono labels
    pub const BODY: f32 = 14.0;

    /*
     * the scrim comes in from the screen's corner instead of sitting behind
     * the text: full strength over the text and off the edges, fading out
     * to the left and below. this is its fade, as a blur in pixels
     */
    pub const WASH: f32 = 120.0;

    /*
     * the wash's edge sits this far past the text, so the text stays on the
     * dense part: a blur spans two deviations, and 1.8 of them in is ~96%,
     * so a long line doesn't run out onto the thin edge
     */
    pub const fn inset() -> f32 {
        WASH * 0.9
    }

    // how far past its edge the wash still shows; it is gone by three deviations
    pub const fn fade() -> f32 {
        WASH * 1.5
    }
}

// the dashboard, across the top: the calendar, what is playing, the notifications
pub mod dash {
    /*
     * its own type steps, a size up from the shared ones: it is read at a
     * glance from across the desk, not typed into. the day stays size::LG
     */
    pub const TEXT: f32 = 20.0;
    pub const SMALL: f32 = 14.0;
    // an event or task line in the agenda, the size of a launcher or clipboard line
    pub const AGENDA: f32 = super::size::MD;

    // three columns this many grid columns wide: the calendar, what is playing, the notifications
    pub const COLUMN: u32 = 4;
    // the middle and right columns start this far down, level with the day's letters, not its line's top
    pub const BESIDE: f32 = 38.0;

    /*
     * the type steps past TEXT and SMALL: the track's title, the month's
     * name and the artist, and a notification's body and the month's numbers
     */
    pub const TITLE: f32 = 32.0;
    pub const TITLE_WEIGHT: super::Weight = super::Weight::Medium;
    pub const HEADING: f32 = 22.0;
    pub const BODY: f32 = 16.0;
    // a notification's summary, a weight up from the body under it
    pub const SUMMARY_WEIGHT: super::Weight = super::Weight::Medium;

    // the month: a day's cell, today's circle, and the dots for what is on
    pub const CELL: f32 = 44.0;
    pub const MARK: f32 = 30.0;
    // between a number, or today's circle, and its dots, so the circle never touches them
    pub const MARK_GAP: f32 = 3.0;
    pub const DOT: f32 = 4.0;
    pub const DOT_GAP: f32 = 3.0;
    pub const DOTS: usize = 3;
    // how strongly the dots show, quieter under the days from the months either side
    pub const DOT_OPACITY: f32 = 0.7;
    pub const OUTSIDE_DOT_OPACITY: f32 = 0.35;
    // the arrows that move between months
    pub const ARROW: f32 = 20.0;

    // the agenda's time column, wide enough for "13:00–14:00"
    pub const TIME: f32 = 118.0;
    /*
     * days listed, today first, and lines across all of them, events and
     * tasks together, so a busy week can't run off the screen
     */
    pub const AGENDA_DAYS: usize = 3;
    pub const AGENDA_LINES: usize = 7;

    // a task's tick in the agenda: an empty ring, filled with a check once done
    pub const TICK: f32 = 18.0;
    pub const TICK_BORDER: f32 = 1.5;
    pub const CHECK: f32 = 12.0;
    // a day with a task due shows a ring beside its event dots, drawn this thick
    pub const RING_BORDER: f32 = 1.0;

    // the cover, at most this big, and only as wide as its column on a small screen
    pub const ART: f32 = 420.0;
    pub const ART_RADIUS: f32 = 10.0;
    pub const PROGRESS: f32 = 3.0;

    // a notification's app icon, and its body cut after this many lines
    pub const ICON: f32 = 40.0;
    pub const BODY_LINES: usize = 2;
}

// settings, top left below where the dashboard starts: the page, its tabs, then its rows
pub mod settings {
    // grid columns wide
    pub const COLUMNS: u32 = 4;
    // rows shown at once; a longer page scrolls with the selection
    pub const ROWS: usize = 10;
    // a row's value is cut to this many characters
    pub const VALUE_CHARS: usize = 20;
    // how much a press or a wheel step moves the volume or the brightness, in percent
    pub const STEP: u8 = 5;
    // the wallpaper preview starts after this many grid columns and spans this many
    pub const PREVIEW_COLUMN: u32 = 5;
    pub const PREVIEW_COLUMNS: u32 = 3;
    // the preview's corners, the album cover's on the dashboard
    pub const PREVIEW_RADIUS: f32 = super::dash::ART_RADIUS;
    // the cached copy of a wallpaper covers at least this much, twice the preview for sharpness
    pub const THUMB_WIDTH: u32 = 864;
    pub const THUMB_HEIGHT: u32 = 540;
}

// the clipboard's preview of the selected clip, and how it tells clips apart
pub mod clipboard {
    // the preview starts after this many grid columns and spans this many, past settings' three for longer lines
    pub const PREVIEW_COLUMN: u32 = 5;
    pub const PREVIEW_COLUMNS: u32 = 4;
    // the most of a clip read for the preview; a long one is cut, a huge image not shown
    pub const TEXT_BYTES: usize = 16 * 1024;
    pub const IMAGE_BYTES: usize = 32 * 1024 * 1024;
    // a hidden clip's dots, always this many so they don't give its length away
    pub const MASK: usize = 14;
    // a password-like clip is one word this long, switching kind of letter at least this often per letter
    pub const SECRET_MIN: usize = 8;
    pub const SECRET_MAX: usize = 64;
    pub const SECRET_SWITCHES: f32 = 0.35;
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
    // a query typed as a sentence, like a task's title, sits smaller so more of it shows
    pub const LONG_QUERY: f32 = 32.0;
    pub const LONG_QUERY_CHARS: usize = 34;
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
    // between groups; space alone sets them apart, so it is a wide step
    pub const GROUP_GAP: f32 = 32.0;
    // between an icon and its text, and between the stats rings
    pub const ITEM_GAP: f32 = 6.0;
    // between the readings an item spells out on hover, "12% cpu  40% mem"
    pub const READING_GAP: f32 = 12.0;
    pub const TEXT: f32 = 14.0;
    pub const TEXT_WEIGHT: super::Weight = super::Weight::Medium;
    // the small size: units after a value and the clock's am/pm
    pub const SMALL: f32 = 12.0;
    // the clock's time, the one thing in the bar a step up
    pub const TIME: f32 = 15.0;
    pub const TIME_WEIGHT: super::Weight = super::Weight::Medium;
    // between the time and its date
    pub const DATE_GAP: f32 = 12.0;
    // symbolic icons next to text
    pub const ICON: f32 = 16.0;
    // the stats and battery rings
    pub const RING: f32 = 14.0;
    pub const RING_STROKE: f32 = 2.0;
    // "artist - title" is cut to this many characters, so a long track can't crowd the clock
    pub const MEDIA_CHARS: usize = 48;
    // the next event's dot
    pub const EVENT_DOT: f32 = 5.0;
    // the event's title, shown while hovered, is cut to this many characters
    pub const EVENT_CHARS: usize = 32;
    // the apps watching a screen share, shown while hovered, are cut to this many characters
    pub const CAST_CHARS: usize = 32;
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

// files yohaku can make again, like tinted icons and album covers
pub fn cache_folder() -> PathBuf {
    let base = env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
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
    // text on a primary fill, like today in the dashboard's month
    pub on_primary: Color,
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
        on_primary: scheme.get("on_primary"),
        error: scheme.get("error"),
    }
}

// the same color at a fraction of its opacity, for the workspace line's quiet tones
pub fn faded(color: Color, opacity: f32) -> Color {
    let alpha = (color.alpha() as f32 * opacity.clamp(0.0, 1.0)).round() as u8;

    Color::rgba(color.red(), color.green(), color.blue(), alpha)
}
