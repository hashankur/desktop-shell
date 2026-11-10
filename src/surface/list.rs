mod view;

use amane::{Key, Service};

pub use view::{Spec, view};

// one row: `id` is what picking it hands back, `name` and `description` are what it shows
#[derive(Clone, PartialEq)]
pub struct Entry {
    pub id: String,
    pub name: String,
    pub description: String,
}

// a label over a run of entries: pinned, recent, matches
pub struct Group {
    pub label: &'static str,
    pub entries: Vec<Entry>,
}

/*
 * the query and the chosen row of whichever list surface is open. only one
 * surface is open at a time, so they share this and opening one starts it over
 */
#[derive(Default)]
pub struct ListState {
    query: String,
    selected: usize,
}

impl Service for ListState {
    fn new() -> Self {
        Self::default()
    }

    // only changes through keys
    fn listen() {}
}

pub fn reset() {
    *ListState::write() = ListState::default();
}

pub fn query() -> String {
    ListState::read().query.clone()
}

// what a key did beyond editing the query and moving the selection
#[derive(Debug, PartialEq)]
pub enum Outcome {
    Edited,
    Enter,
    Tab,
    Ignored,
}

/*
 * typing goes straight to the search, up and down move the selection and
 * wrap; enter and tab are the surface's to act on. `count` says how many
 * rows a query shows, which the wrap needs
 */
pub fn handle(key: Key, count: impl Fn(&str) -> usize) -> Outcome {
    let mut state = ListState::write();

    let rows = count(&state.query);

    match key {
        Key::Character(letter) => {
            state.query.push(letter);
            state.selected = 0;
        }

        // a leading space would search for nothing
        Key::Space if !state.query.is_empty() => {
            state.query.push(' ');
            state.selected = 0;
        }

        Key::Backspace => {
            state.query.pop();
            state.selected = 0;
        }

        Key::Down if rows > 0 => state.selected = (state.selected + 1) % rows,

        Key::Up if rows > 0 => state.selected = (state.selected + rows - 1) % rows,

        Key::Enter => return Outcome::Enter,

        Key::Tab => return Outcome::Tab,

        _ => return Outcome::Ignored,
    }

    Outcome::Edited
}

// the chosen row of the groups the list shows
pub fn picked(groups: Vec<Group>) -> Option<Entry> {
    let selected = ListState::read().selected;

    groups
        .into_iter()
        .flat_map(|group| group.entries)
        .nth(selected)
}

pub fn count(groups: &[Group]) -> usize {
    groups.iter().map(|group| group.entries.len()).sum()
}
