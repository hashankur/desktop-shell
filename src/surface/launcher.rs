mod history;

use amane::{Apps, DesktopApp, Key, Monitor, Rectangle, Service};

use super::list::{self, Entry, Group, Outcome, Spec};
use super::{Kind, Surface, search};
use crate::theme::Theme;

// how many results fit the surface's fixed list
const RESULTS: usize = 9;

fn entry(app: &DesktopApp) -> Entry {
    Entry {
        // apps are told apart by name, which is what the pins and recents store
        id: app.name().to_string(),
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
fn groups(query: &str) -> Vec<Group> {
    let apps = Apps::read();
    let apps = apps.list();

    if apps.is_empty() {
        return vec![Group {
            label: "apps are loading",
            entries: Vec::new(),
        }];
    }

    if query.is_empty() {
        return resting(apps);
    }

    let mut scored: Vec<(f32, &DesktopApp)> = apps
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
fn resting(apps: &[DesktopApp]) -> Vec<Group> {
    let find = |name: &String| apps.iter().find(|app| app.name() == name.as_str());

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
            entries: apps.iter().take(RESULTS).map(entry).collect(),
        });
    }

    groups
}

pub fn view(theme: &Theme, monitor: &Monitor) -> Rectangle {
    let spec = Spec {
        placeholder: "apps",
        groups: groups(&list::query()),
        hints: &["↵ open", "tab clipboard", "esc close"],
        pick: launch,
    };

    list::view(theme, monitor, spec)
}

// starts the app, remembers it, and closes the surface
fn launch(name: &str) {
    if let Some(app) = Apps::read().list().iter().find(|app| app.name() == name) {
        app.launch();
    }

    history::record(name);

    Surface::close();
}

pub fn key(key: Key) {
    match list::handle(key, |query| list::count(&groups(query))) {
        Outcome::Enter => {
            if let Some(entry) = list::picked(groups(&list::query())) {
                launch(&entry.id);
            }
        }

        Outcome::Tab => Surface::open(Kind::Clipboard),

        Outcome::Edited | Outcome::Ignored => {}
    }
}
