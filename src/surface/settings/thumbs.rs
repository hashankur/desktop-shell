use std::collections::HashMap;
use std::ffi::OsString;
use std::fs;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::UNIX_EPOCH;

use amane::Service;

use super::Settings;
use crate::files;
use crate::theme::{self, settings};

// what the appearance page knows about a wallpaper beyond its name
#[derive(Clone, Default, PartialEq)]
pub struct Picture {
    // a small copy for the preview, only set once it is whole on disk: amane remembers a picture it failed to decode
    pub thumb: Option<PathBuf>,

    // the wallpaper's own width and height
    pub size: Option<(u32, u32)>,
}

impl Picture {
    pub fn resolution(&self) -> Option<String> {
        self.size.map(|(width, height)| format!("{width}×{height}"))
    }
}

// one look-up at a time; opening settings again while it runs leaves it to finish
static RUNNING: AtomicBool = AtomicBool::new(false);

// lets the next look-up run however this one ends
struct Running;

impl Drop for Running {
    fn drop(&mut self) {
        RUNNING.store(false, Ordering::Release);
    }
}

/*
 * finds or makes the small copy and the size of every wallpaper, off the ui
 * thread. the wallpapers are full size, some 5k wide, far too big to decode
 * each time the selection moves, so a copy is kept in yohaku's cache, named
 * after the file's path, size and age so a changed file gets a new one. the
 * ones already cached go to the page at once, the rest one by one, the
 * wallpaper in use first
 */
pub fn look_up(wallpapers: Vec<PathBuf>, first: Option<PathBuf>) {
    if RUNNING.swap(true, Ordering::AcqRel) {
        return;
    }

    thread::spawn(move || {
        let _running = Running;

        let folder = theme::cache_folder().join("thumbs");

        let mut cached = HashMap::new();
        let mut missing = Vec::new();

        for path in wallpapers {
            match find(&folder, &path) {
                Some(picture) => {
                    cached.insert(path, picture);
                }
                None => missing.push(path),
            }
        }

        if !cached.is_empty() {
            store(cached);
        }

        if let Some(index) = first.and_then(|first| missing.iter().position(|path| *path == first)) {
            let path = missing.remove(index);
            missing.insert(0, path);
        }

        for path in missing {
            if let Some(picture) = make(&folder, &path) {
                store(HashMap::from([(path, picture)]));
            }
        }
    });
}

// writes only what is new, since a write redraws the surface
fn store(found: HashMap<PathBuf, Picture>) {
    let changed = {
        let settings = Settings::read();

        found
            .iter()
            .any(|(path, picture)| settings.pictures.get(path) != Some(picture))
    };

    if changed {
        Settings::write().pictures.extend(found);
    }
}

fn key(path: &Path) -> Option<String> {
    let meta = fs::metadata(path).ok()?;
    let modified = meta.modified().ok()?.duration_since(UNIX_EPOCH).ok()?.as_secs();

    let mut hasher = DefaultHasher::new();

    path.hash(&mut hasher);
    modified.hash(&mut hasher);
    meta.len().hash(&mut hasher);

    Some(format!("{:016x}", hasher.finish()))
}

fn find(folder: &Path, path: &Path) -> Option<Picture> {
    let key = key(path)?;
    let thumb = folder.join(format!("{key}.jpg"));

    let size = fs::read_to_string(folder.join(format!("{key}.size")))
        .ok()
        .and_then(|text| parse_size(&text))?;

    thumb.is_file().then_some(Picture {
        thumb: Some(thumb),
        size: Some(size),
    })
}

/*
 * one magick call reads the size and writes the copy; the copy is written
 * aside and moved in, so a decode never sees half a file
 */
fn make(folder: &Path, path: &Path) -> Option<Picture> {
    let key = key(path)?;

    fs::create_dir_all(folder).ok()?;

    let thumb = folder.join(format!("{key}.jpg"));
    let partial = folder.join(format!("{key}.part.jpg"));

    // only the first frame of anything animated
    let mut source = OsString::from(path.as_os_str());
    source.push("[0]");

    let fit = format!("{}x{}^", settings::THUMB_WIDTH, settings::THUMB_HEIGHT);

    let output = Command::new("magick")
        .arg(source)
        .args(["-format", "%w %h", "-write", "info:-", "-thumbnail", &fit, "-quality", "85"])
        .arg(&partial)
        .output()
        .ok()?;

    if !output.status.success() || fs::rename(&partial, &thumb).is_err() {
        let _ = fs::remove_file(&partial);

        return None;
    }

    let size = parse_size(&String::from_utf8_lossy(&output.stdout));

    if let Some((width, height)) = size {
        let _ = files::write_atomic(&folder.join(format!("{key}.size")), &format!("{width} {height}"));
    }

    Some(Picture {
        thumb: Some(thumb),
        size,
    })
}

fn parse_size(text: &str) -> Option<(u32, u32)> {
    let mut parts = text.split_whitespace();

    let width = parts.next()?.parse().ok()?;
    let height = parts.next()?.parse().ok()?;

    Some((width, height))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_the_size_magick_prints() {
        assert_eq!(parse_size("5120 2850"), Some((5120, 2850)));
        assert_eq!(parse_size("1920 1080\n"), Some((1920, 1080)));
        assert_eq!(parse_size(""), None);
        assert_eq!(parse_size("wide tall"), None);
        assert_eq!(parse_size("1920"), None);
    }

    #[test]
    fn writes_the_resolution_with_a_times_sign() {
        let picture = Picture {
            thumb: None,
            size: Some((3840, 1609)),
        };

        assert_eq!(picture.resolution().as_deref(), Some("3840×1609"));
        assert_eq!(Picture::default().resolution(), None);
    }
}
