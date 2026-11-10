mod parse;

use std::thread;

use amane::{Key, Monitor, Rectangle, Service};

use super::list::{self, Entry, Group, Outcome, Spec};
use super::{Kind, Surface, search};
use crate::theme::Theme;

// how many results fit the surface's fixed list
const RESULTS: usize = 9;

// the history as `cliphist list` last gave it, newest first
#[derive(Default)]
pub struct Clipboard {
    entries: Vec<Entry>,
}

impl Service for Clipboard {
    fn new() -> Self {
        Self::default()
    }

    // only changes when the surface opens
    fn listen() {}
}

/*
 * asked again every time the surface opens, off the ui thread; the last
 * list stays on screen until the new one arrives, and a failed call (no
 * cliphist) keeps it empty instead of crashing
 */
pub fn refresh() {
    thread::spawn(|| {
        let entries = parse::entries(&amane::output("cliphist list"));

        if Clipboard::read().entries != entries {
            Clipboard::write().entries = entries;
        }
    });
}

fn groups(query: &str) -> Vec<Group> {
    let clipboard = Clipboard::read();
    let entries = &clipboard.entries;

    if query.is_empty() {
        let label = if entries.is_empty() {
            "nothing copied yet"
        } else {
            "history"
        };

        return vec![Group {
            label,
            entries: entries.iter().take(RESULTS).cloned().collect(),
        }];
    }

    let mut scored: Vec<(f32, &Entry)> = entries
        .iter()
        .filter_map(|entry| search::score(query, &entry.name).map(|score| (score, entry)))
        .collect();

    scored.sort_by(|a, b| b.0.total_cmp(&a.0));

    let matches: Vec<Entry> = scored
        .into_iter()
        .take(RESULTS)
        .map(|(_, entry)| entry.clone())
        .collect();

    let label = if matches.is_empty() {
        "nothing matches"
    } else {
        "matches"
    };

    vec![Group {
        label,
        entries: matches,
    }]
}

pub fn view(theme: &Theme, monitor: &Monitor) -> Rectangle {
    let spec = Spec {
        placeholder: "clipboard",
        groups: groups(&list::query()),
        hints: &["↵ copy", "tab apps", "esc close"],
        pick: copy,
    };

    list::view(theme, monitor, spec)
}

// puts the entry back on the clipboard and closes the surface
fn copy(id: &str) {
    // ids come from cliphist's own list, checked there; this guards the command anyway
    if !id.is_empty() && id.bytes().all(|byte| byte.is_ascii_digit()) {
        amane::spawn(&format!("cliphist decode {id} | wl-copy"));
    }

    Surface::close();
}

pub fn key(key: Key) {
    match list::handle(key, |query| list::count(&groups(query))) {
        Outcome::Enter => {
            if let Some(entry) = list::picked(groups(&list::query())) {
                copy(&entry.id);
            }
        }

        Outcome::Tab => Surface::open(Kind::Launcher),

        Outcome::Edited | Outcome::Ignored => {}
    }
}
