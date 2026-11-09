mod index;
mod recolor;

use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};

use amane::{Color, Service};

use index::{index_apps, index_symbolic};
use recolor::recolor;

/*
 * symbolic icons, tinted to an exact theme color. the svgs ship with a dark
 * fill baked in (#2e3436, #000, or none at all), so like gtk every color in
 * them is rewritten to the one asked for, and each tinted copy is written
 * once per run into yohaku's cache, since amane draws images from files
 */
#[derive(Default)]
pub struct Icons {
    // "audio-volume-high" -> its symbolic svg, nearest theme first
    symbolic: HashMap<String, PathBuf>,

    // a desktop file id or StartupWMClass, lowercased -> its Icon= name
    app_icons: HashMap<String, String>,
}

impl Service for Icons {
    // empty at first: walking the themes takes a moment, so it happens in listen
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        let icons = Icons {
            symbolic: index_symbolic(),
            app_icons: index_apps(),
        };

        *Self::write() = icons;
    }
}

impl Icons {
    // the symbolic icon for a window's app id, tried as its desktop file names it, then as itself
    fn app_name(&self, app_id: &str) -> Option<&str> {
        let lower = app_id.to_lowercase();

        let named = self.app_icons.get(&lower).map(String::as_str);

        // the key is returned, not the candidate, which may borrow from `lower`
        [named, Some(app_id), Some(lower.as_str())]
            .into_iter()
            .flatten()
            .find_map(|name| self.symbolic.get_key_value(name))
            .map(|(name, _)| name.as_str())
    }
}

// (icon name, color) -> the tinted copy, or None when it couldn't be written
type Tinted = HashMap<(String, [u8; 3]), Option<PathBuf>>;

// each copy is written once per run
static TINTED: Mutex<Option<Tinted>> = Mutex::new(None);

// a symbolic icon by name, without "-symbolic", tinted to the color; None if no theme has it
pub fn symbolic(name: &str, color: Color) -> Option<PathBuf> {
    let source = Icons::read().symbolic.get(name).cloned()?;

    tinted(name, &source, color)
}

// the focused window's icon, only where a symbolic one exists: full-color app icons stay out of the bar
pub fn app(app_id: &str, color: Color) -> Option<PathBuf> {
    let icons = Icons::read();

    let name = icons.app_name(app_id)?.to_string();
    let source = icons.symbolic.get(&name).cloned()?;

    drop(icons);

    tinted(&name, &source, color)
}

fn tinted(name: &str, source: &Path, color: Color) -> Option<PathBuf> {
    let rgb = [color.red(), color.green(), color.blue()];
    let key = (name.to_string(), rgb);

    let mut cache = TINTED.lock().unwrap_or_else(PoisonError::into_inner);
    let cache = cache.get_or_insert_with(HashMap::new);

    if let Some(found) = cache.get(&key) {
        return found.clone();
    }

    let made = write_tinted(name, source, rgb);

    cache.insert(key, made.clone());

    made
}

fn write_tinted(name: &str, source: &Path, [red, green, blue]: [u8; 3]) -> Option<PathBuf> {
    let hex = format!("#{red:02x}{green:02x}{blue:02x}");

    let svg = recolor(&fs::read_to_string(source).ok()?, &hex);

    let folder = cache_folder();
    fs::create_dir_all(&folder).ok()?;

    let path = folder.join(format!("{name}-{}.svg", &hex[1..]));

    // written aside and moved in, so a decode never sees half a file
    let partial = path.with_extension("svg.part");
    fs::write(&partial, svg).ok()?;
    fs::rename(&partial, &path).ok()?;

    Some(path)
}

fn cache_folder() -> PathBuf {
    let base = env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
        .unwrap_or_else(|| PathBuf::from("/tmp"));

    base.join("yohaku/icons")
}
