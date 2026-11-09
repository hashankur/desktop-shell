mod history;
mod search;
mod view;

use amane::{Apps, DesktopApp, Key, Service};

use super::Surface;

pub use view::view;

// how many results fit the surface's fixed list
const RESULTS: usize = 9;

// what the query and selection are, kept here so the window's key handler and the view agree
#[derive(Default)]
pub struct Launcher {
    query: String,
    selected: usize,
}

impl Service for Launcher {
    fn new() -> Self {
        Self::default()
    }

    // only changes through keys
    fn listen() {}
}

pub struct Entry {
    pub name: String,
    pub description: String,
}

// a label over a run of entries: pinned, recent, matches
pub struct Group {
    pub label: &'static str,
    pub entries: Vec<Entry>,
}

// opening starts from an empty search at the top of the list
pub fn reset() {
    *Launcher::write() = Launcher::default();
}

fn entry(app: &DesktopApp) -> Entry {
    Entry {
        name: app.name().to_string(),
        description: app.description().unwrap_or_default().to_string(),
    }
}

/*
 * what the list shows. an empty query shows the pinned apps, then the
 * recent ones; a query shows the best matches. amane's app scan starts
 * empty and takes a few seconds, so an empty list says so instead of
 * looking broken
 */
pub fn groups(query: &str) -> Vec<Group> {
    let apps = Apps::read();
    let list = apps.list();

    if list.is_empty() {
        return vec![Group {
            label: "apps are loading",
            entries: Vec::new(),
        }];
    }

    if query.is_empty() {
        return resting(list);
    }

    let mut scored: Vec<(f32, &DesktopApp)> = list
        .iter()
        .filter_map(|app| search::score(query, app.name()).map(|score| (score, app)))
        .collect();

    scored.sort_by(|a, b| b.0.total_cmp(&a.0));

    let entries: Vec<Entry> = scored
        .into_iter()
        .take(RESULTS)
        .map(|(_, app)| entry(app))
        .collect();

    let label = if entries.is_empty() {
        "nothing matches"
    } else {
        "matches"
    };

    vec![Group { label, entries }]
}

// pinned, then recent without the pinned ones; the first apps alphabetically when there is neither
fn resting(list: &[DesktopApp]) -> Vec<Group> {
    let find = |name: &String| list.iter().find(|app| app.name() == name.as_str());

    let pinned_names = history::pinned();

    let pinned: Vec<Entry> = pinned_names.iter().filter_map(find).map(entry).collect();

    let recent: Vec<Entry> = history::recent()
        .iter()
        .filter(|name| !pinned_names.contains(name))
        .filter_map(find)
        .map(entry)
        .take(RESULTS.saturating_sub(pinned.len()))
        .collect();

    let mut groups = Vec::new();

    if !pinned.is_empty() {
        groups.push(Group {
            label: "pinned",
            entries: pinned.into_iter().take(RESULTS).collect(),
        });
    }

    if !recent.is_empty() {
        groups.push(Group {
            label: "recent",
            entries: recent,
        });
    }

    if groups.is_empty() {
        groups.push(Group {
            label: "apps",
            entries: list.iter().take(RESULTS).map(entry).collect(),
        });
    }

    groups
}

// starts the app, remembers it, and closes the surface
pub fn launch(name: &str) {
    if let Some(app) = Apps::read().list().iter().find(|app| app.name() == name) {
        app.launch();
    }

    history::record(name);

    Surface::close();
}

// typing goes straight to the search; escape is the surface's, not ours
pub fn key(key: Key) {
    let mut launcher = Launcher::write();

    let count: usize = groups(&launcher.query)
        .iter()
        .map(|group| group.entries.len())
        .sum();

    match key {
        Key::Character(letter) => {
            launcher.query.push(letter);
            launcher.selected = 0;
        }

        // a leading space would search for nothing
        Key::Space if !launcher.query.is_empty() => {
            launcher.query.push(' ');
            launcher.selected = 0;
        }

        Key::Backspace => {
            launcher.query.pop();
            launcher.selected = 0;
        }

        Key::Down if count > 0 => launcher.selected = (launcher.selected + 1) % count,

        Key::Up if count > 0 => launcher.selected = (launcher.selected + count - 1) % count,

        Key::Enter => {
            let query = launcher.query.clone();
            let selected = launcher.selected;

            // the handler below closes the surface, which writes another service
            drop(launcher);

            let name = groups(&query)
                .into_iter()
                .flat_map(|group| group.entries)
                .nth(selected)
                .map(|entry| entry.name);

            if let Some(name) = name {
                launch(&name);
            }
        }

        _ => {}
    }
}
