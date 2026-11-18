mod decode;
mod kind;
mod parse;
mod preview;
mod text;

use std::thread;

use amane::{Key, Monitor, Rectangle, Service};

use super::list::{self, Entry, Group, Outcome, Spec};
use super::{Surface, search};
use crate::theme::{Theme, clipboard};
use decode::Preview;
use kind::Kind;
use parse::Clip;

// how many results fit the surface's fixed list
const RESULTS: usize = 9;

#[derive(Default)]
pub struct Clipboard {
    // the history as `cliphist list` last gave it, newest first
    clips: Vec<Clip>,

    // the selected clip read in full, or the last one that was
    preview: Option<Preview>,

    // the hidden clip shown for now, until the selection moves or the surface closes
    revealed: Option<String>,
}

impl Service for Clipboard {
    fn new() -> Self {
        Self::default()
    }

    // only changes when the surface opens and as the selection moves
    fn listen() {}
}

/*
 * asked again every time the surface opens, off the ui thread; the last
 * list stays on screen until the new one arrives, and a failed call (no
 * cliphist) keeps it empty instead of crashing
 */
pub fn refresh() {
    {
        let mut state = Clipboard::write();

        state.revealed = None;
        state.preview = None;
    }

    thread::spawn(|| {
        let clips = parse::clips(&amane::output("cliphist list"));

        decode::forget_except(&clips);

        if Clipboard::read().clips != clips {
            Clipboard::write().clips = clips;
        }

        want_selected();
    });
}

// the clips a query shows, best first, at most a list's worth
fn shown(query: &str) -> Vec<Clip> {
    let clipboard = Clipboard::read();
    let clips = &clipboard.clips;

    if query.is_empty() {
        return clips.iter().take(RESULTS).cloned().collect();
    }

    let mut scored: Vec<(f32, &Clip)> = clips
        .iter()
        .filter_map(|clip| search::score(query, &clip.text).map(|score| (score, clip)))
        .collect();

    scored.sort_by(|a, b| b.0.total_cmp(&a.0));

    scored
        .into_iter()
        .take(RESULTS)
        .map(|(_, clip)| clip.clone())
        .collect()
}

fn groups(query: &str) -> Vec<Group> {
    let clips = shown(query);
    let revealed = Clipboard::read().revealed.clone();

    let label = match (query.is_empty(), clips.is_empty()) {
        (true, true) => "nothing copied yet",
        (true, false) => "history",
        (false, true) => "nothing matches",
        (false, false) => "matches",
    };

    let entries = clips
        .iter()
        .map(|clip| entry(clip, revealed.as_deref() == Some(clip.id.as_str())))
        .collect();

    vec![Group { label, entries }]
}

// a row: a hidden clip is dots until shown, and the note says what kind of clip it is
fn entry(clip: &Clip, revealed: bool) -> Entry {
    let name = if clip.kind == Kind::Secret && !revealed {
        "•".repeat(clipboard::MASK)
    } else {
        clip.text.clone()
    };

    let description = match &clip.kind {
        Kind::Text => String::new(),
        Kind::Link(host) => host.clone(),
        Kind::Path => String::from("path"),
        Kind::Secret => String::from("hidden"),
        Kind::Image { weight, .. } => weight.clone(),
    };

    Entry {
        id: clip.id.clone(),
        name,
        description,
    }
}

fn selected() -> Option<Clip> {
    shown(&list::query()).into_iter().nth(list::selected())
}

// a hidden clip is only read once it is shown
fn want_selected() {
    let Some(clip) = selected() else {
        return;
    };

    let revealed = Clipboard::read().revealed.as_deref() == Some(clip.id.as_str());

    if clip.kind != Kind::Secret || revealed {
        decode::want(&clip);
    }
}

pub fn view(theme: &Theme, monitor: &Monitor) -> Rectangle {
    let clip = selected();

    let state = Clipboard::read();
    let preview = state.preview.clone();
    let revealed = clip
        .as_ref()
        .is_some_and(|clip| state.revealed.as_deref() == Some(clip.id.as_str()));
    drop(state);

    let secret = clip.as_ref().is_some_and(|clip| clip.kind == Kind::Secret);

    let hints: &[&str] = match (secret, revealed) {
        (true, false) => &["↵ copy", "→ show", "tab apps", "esc close"],
        (true, true) => &["↵ copy", "→ hide", "tab apps", "esc close"],
        _ => &["↵ copy", "tab apps", "esc close"],
    };

    let spec = Spec {
        placeholder: "clipboard",
        groups: groups(&list::query()),
        hints,
        pick: copy,
        long_query: false,
        beside: preview::beside(theme, clip.as_ref(), preview.as_ref(), revealed, monitor.width as f32),
    };

    list::view(theme, monitor, spec)
}

// puts the entry back on the clipboard and closes the surface
fn copy(id: &str) {
    // ids come from cliphist's own list, checked there; this guards the command anyway
    if parse::is_id(id) {
        amane::spawn(&format!("cliphist decode {id} | wl-copy"));
    }

    Surface::close();
}

/*
 * → shows the selected clip if it is hidden, and hides it again. amane
 * doesn't report a key being let go, so it can't be shown only while a key
 * is held; any other key hides it instead
 */
fn toggle() {
    let Some(clip) = selected() else {
        return;
    };

    if clip.kind != Kind::Secret {
        return;
    }

    {
        let mut state = Clipboard::write();

        state.revealed = match state.revealed {
            Some(ref id) if *id == clip.id => None,
            _ => Some(clip.id),
        };
    }

    want_selected();
}

fn hide() {
    if Clipboard::read().revealed.is_some() {
        Clipboard::write().revealed = None;
    }
}

pub fn key(key: Key) {
    if key == Key::Right {
        toggle();

        return;
    }

    hide();

    match list::handle(key, |query| list::count(&groups(query))) {
        Outcome::Enter => {
            if let Some(entry) = list::picked(groups(&list::query())) {
                copy(&entry.id);
            }
        }

        Outcome::Tab => Surface::open(super::Kind::Launcher),

        Outcome::Edited => want_selected(),

        Outcome::Ignored => {}
    }
}
