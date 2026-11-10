use std::fs;
use std::path::PathBuf;

use crate::files;
use crate::theme;

// how many recently launched apps are remembered
const RECENT_LIMIT: usize = 8;

/*
 * pinned and recent apps, both by app name since that is what a desktop
 * entry offers to tell them apart. pins are a hand-edited file of names,
 * one per line, in yohaku's config folder; without the file there are no
 * pins. recents are written by the launcher itself, into yohaku's state
 */
fn pinned_path() -> PathBuf {
    theme::config_folder().join("pinned")
}

fn recent_path() -> PathBuf {
    theme::state_folder().join("recent")
}

fn read_names(path: &PathBuf) -> Vec<String> {
    fs::read_to_string(path)
        .unwrap_or_default()
        .lines()
        .map(str::trim)
        // a line starting with # is a note
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
        .map(String::from)
        .collect()
}

pub fn pinned() -> Vec<String> {
    read_names(&pinned_path())
}

pub fn recent() -> Vec<String> {
    read_names(&recent_path())
}

// puts the app first in the recents, once, and keeps the newest few
pub fn record(name: &str) {
    let mut names = recent();

    names.retain(|existing| existing != name);
    names.insert(0, name.to_string());
    names.truncate(RECENT_LIMIT);

    // a recents list that can't be saved only costs the ordering, never the launch
    let _ = files::write_atomic(&recent_path(), &names.join("\n"));
}
