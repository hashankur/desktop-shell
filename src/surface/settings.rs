mod actions;
mod preview;
mod rows;
mod thumbs;
mod view;

use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::{Mutex, PoisonError};

use amane::{Bluetooth, Key, Network, Scroll, Service};

pub use view::view;

use crate::wallpaper::Wallpaper;

#[derive(Clone, Copy, Default, PartialEq)]
pub enum Page {
    #[default]
    Quick,
    Network,
    Bluetooth,
    Appearance,
}

impl Page {
    pub const ALL: [Page; 4] = [Page::Quick, Page::Network, Page::Bluetooth, Page::Appearance];

    pub fn name(self) -> &'static str {
        match self {
            Page::Quick => "quick",
            Page::Network => "network",
            Page::Bluetooth => "bluetooth",
            Page::Appearance => "appearance",
        }
    }

    fn index(self) -> usize {
        Self::ALL.iter().position(|page| *page == self).unwrap_or(0)
    }

    // the next page along, wrapping at either end
    fn step(self, forward: bool) -> Page {
        let count = Self::ALL.len();
        let index = if forward { self.index() + 1 } else { self.index() + count - 1 };

        Self::ALL[index % count]
    }
}

/*
 * the open page and its selected row, and what settings looks up when it
 * opens: the power profile and the wallpapers folder. it opens on the
 * quick page every time, like the other surfaces start over
 */
#[derive(Default)]
pub struct Settings {
    page: Page,
    selected: usize,
    profile: Option<String>,
    wallpapers: Vec<PathBuf>,
    // the small copy and size of each wallpaper, filled in as they are found
    pictures: HashMap<PathBuf, thumbs::Picture>,
}

impl Service for Settings {
    fn new() -> Self {
        Self::default()
    }

    // only changes through keys, clicks and what opening looks up
    fn listen() {}
}

pub fn reset() {
    let wallpapers = wallpapers();

    {
        let mut settings = Settings::write();

        settings.page = Page::Quick;
        settings.selected = 0;
        settings.wallpapers = wallpapers.clone();
    }

    actions::read_profile();

    thumbs::look_up(wallpapers, Wallpaper::read().path().map(PathBuf::from));
}

// a bluetooth scan only runs while it can be watched
pub fn leave() {
    if Bluetooth::read().scanning() {
        Bluetooth::stop_scan();
    }
}

fn open_page(page: Page) {
    {
        let mut settings = Settings::write();

        if settings.page == page {
            return;
        }

        settings.page = page;
        settings.selected = 0;
    }

    match page {
        // the list of networks is only as fresh as the last scan
        Page::Network => Network::scan(),

        // the wallpapers open on the one in use, scrolled to it
        Page::Appearance => {
            let current = Wallpaper::read().path().map(PathBuf::from);

            let index = rows::rows(page).iter().position(|row| {
                matches!(&row.action, rows::Action::Wallpaper(path) if Some(path) == current.as_ref())
            });

            if let Some(index) = index {
                select(index);
            }
        }

        _ => {}
    }
}

// a page by its name, from ipc; an unknown name leaves the page as it is
pub fn show_page(name: &str) {
    if let Some(page) = Page::ALL.into_iter().find(|page| page.name() == name) {
        open_page(page);
    }
}

fn select(index: usize) {
    if Settings::read().selected != index {
        Settings::write().selected = index;
    }
}

// a click on a row picks it and does what enter would
fn choose(index: usize) {
    select(index);

    let page = Settings::read().page;

    if let Some(row) = rows::rows(page).get(index) {
        actions::run(&row.action);
    }
}

// scrolling not yet worth a step, in lines
static SCROLLED: Mutex<f32> = Mutex::new(0.0);

/*
 * the wheel over a level row moves it a step per line, up for more. a
 * touchpad sends many small fractions of a line, so they add up first
 */
fn scroll(index: usize, scroll: Scroll) {
    let lines = {
        let mut scrolled = SCROLLED.lock().unwrap_or_else(PoisonError::into_inner);

        *scrolled += scroll.y;

        let whole = scrolled.trunc();
        *scrolled -= whole;

        whole
    };

    if lines == 0.0 {
        return;
    }

    let page = Settings::read().page;

    if let Some(row) = rows::rows(page).get(index) {
        actions::adjust(&row.action, lines < 0.0);
    }
}

/*
 * left and right turn the page, up and down pick a row, enter acts on it,
 * and minus and plus move a level
 */
pub fn key(key: Key) {
    let (page, selected) = {
        let settings = Settings::read();
        (settings.page, settings.selected)
    };

    let rows = rows::rows(page);
    let last = rows.len().saturating_sub(1);

    // networks and devices come and go, so the list may have shrunk under the selection
    let selected = selected.min(last);

    match key {
        Key::Right | Key::Tab => open_page(page.step(true)),

        Key::Left => open_page(page.step(false)),

        Key::Down => select((selected + 1).min(last)),

        Key::Up => select(selected.saturating_sub(1)),

        Key::Home => select(0),

        Key::End => select(last),

        Key::Enter | Key::Space => {
            if let Some(row) = rows.get(selected) {
                actions::run(&row.action);
            }
        }

        Key::Character('-' | '_') => {
            if let Some(row) = rows.get(selected) {
                actions::adjust(&row.action, false);
            }
        }

        Key::Character('=' | '+') => {
            if let Some(row) = rows.get(selected) {
                actions::adjust(&row.action, true);
            }
        }

        _ => {}
    }
}

// pictures directly in ~/Pictures/Wallpapers, by name
fn wallpapers() -> Vec<PathBuf> {
    let Some(home) = std::env::var_os("HOME") else {
        return Vec::new();
    };

    let Ok(entries) = fs::read_dir(PathBuf::from(home).join("Pictures/Wallpapers")) else {
        return Vec::new();
    };

    let mut pictures: Vec<PathBuf> = entries
        .filter_map(|entry| entry.ok().map(|entry| entry.path()))
        .filter(|path| path.is_file() && is_picture(path))
        .collect();

    pictures.sort();

    pictures
}

fn is_picture(path: &std::path::Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| {
            matches!(extension.to_ascii_lowercase().as_str(), "jpg" | "jpeg" | "png" | "webp")
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pages_wrap_both_ways() {
        assert_eq!(Page::Quick.step(true).name(), "network");
        assert_eq!(Page::Appearance.step(true).name(), "quick");
        assert_eq!(Page::Quick.step(false).name(), "appearance");
    }

    #[test]
    fn knows_pictures() {
        assert!(is_picture(std::path::Path::new("/a/b.JPG")));
        assert!(is_picture(std::path::Path::new("/a/b.webp")));
        assert!(!is_picture(std::path::Path::new("/a/b.txt")));
        assert!(!is_picture(std::path::Path::new("/a/b")));
    }
}
