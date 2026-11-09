use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

// MoreWaita first, Adwaita for what it lacks, hicolor for what apps ship themselves
const THEMES: [&str; 3] = ["MoreWaita", "Adwaita", "hicolor"];

// where themes keep symbolic svgs; the fixed-size folders only hold pngs
const THEME_FOLDERS: [&str; 2] = ["symbolic", "scalable"];

const SUFFIX: &str = "-symbolic.svg";

// $XDG_DATA_HOME first, then $XDG_DATA_DIRS, as the spec orders them
fn data_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();

    match env::var_os("XDG_DATA_HOME") {
        Some(home) => dirs.push(PathBuf::from(home)),
        None => {
            if let Some(home) = env::var_os("HOME") {
                dirs.push(PathBuf::from(home).join(".local/share"));
            }
        }
    }

    let shared = env::var("XDG_DATA_DIRS").unwrap_or_else(|_| String::from("/usr/local/share:/usr/share"));

    dirs.extend(shared.split(':').filter(|dir| !dir.is_empty()).map(PathBuf::from));

    dirs
}

pub fn index_symbolic() -> HashMap<String, PathBuf> {
    let mut index = HashMap::new();

    let dirs = data_dirs();

    // earlier themes and earlier dirs win, so only fill names not seen yet
    for theme in THEMES {
        for dir in &dirs {
            for folder in THEME_FOLDERS {
                walk(&dir.join("icons").join(theme).join(folder), &mut |path| {
                    let Some(file) = path.file_name().and_then(|file| file.to_str()) else {
                        return;
                    };

                    if let Some(name) = file.strip_suffix(SUFFIX) {
                        index.entry(name.to_string()).or_insert_with(|| path.to_path_buf());
                    }
                });
            }
        }
    }

    index
}

/*
 * a window's app id is usually its desktop file id or StartupWMClass, and
 * the file's Icon= names the icon, which often differs (zen-beta -> zen-browser)
 */
pub fn index_apps() -> HashMap<String, String> {
    let mut index = HashMap::new();

    for dir in data_dirs() {
        let applications = dir.join("applications");

        walk(&applications, &mut |path| {
            if path.extension().is_none_or(|extension| extension != "desktop") {
                return;
            }

            let Ok(text) = fs::read_to_string(path) else {
                return;
            };

            let Some(icon) = entry_key(&text, "Icon") else {
                return;
            };

            // the id is the path inside applications/, with / turned into -
            let id = path
                .strip_prefix(&applications)
                .ok()
                .and_then(|relative| relative.to_str())
                .and_then(|relative| relative.strip_suffix(".desktop"))
                .map(|relative| relative.replace('/', "-"));

            let class = entry_key(&text, "StartupWMClass");

            for key in [id, class].into_iter().flatten() {
                index.entry(key.to_lowercase()).or_insert_with(|| icon.clone());
            }
        });
    }

    index
}

// a key from the [Desktop Entry] group only, not from its actions
fn entry_key(text: &str, key: &str) -> Option<String> {
    let mut in_entry = false;

    for line in text.lines() {
        let line = line.trim();

        if line.starts_with('[') {
            in_entry = line == "[Desktop Entry]";
            continue;
        }

        if !in_entry {
            continue;
        }

        let Some((name, value)) = line.split_once('=') else {
            continue;
        };

        if name.trim() == key {
            let value = value.trim();

            return (!value.is_empty()).then(|| value.to_string());
        }
    }

    None
}

// every file under a folder, following links, since nix builds these trees from them
fn walk(folder: &Path, visit: &mut dyn FnMut(&Path)) {
    let Ok(entries) = fs::read_dir(folder) else {
        return;
    };

    for entry in entries.filter_map(Result::ok) {
        let path = entry.path();

        // metadata follows links, file_type wouldn't
        let Ok(metadata) = fs::metadata(&path) else {
            continue;
        };

        if metadata.is_dir() {
            walk(&path, visit);
        } else {
            visit(&path);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_only_the_desktop_entry_group() {
        let text = "[Desktop Entry]\nName=Zen\nIcon=zen-browser\n\n[Desktop Action new]\nIcon=other\n";

        assert_eq!(entry_key(text, "Icon").as_deref(), Some("zen-browser"));
        assert_eq!(entry_key(text, "StartupWMClass"), None);
    }
}
