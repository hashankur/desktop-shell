use amane::Service;

/*
 * which clickable item the pointer is over; hover feedback is the item's
 * text and icon turning primary, never a fill. keys carry the monitor name,
 * so the same item on another bar doesn't light up with it
 */
#[derive(Default)]
pub struct Hover {
    key: Option<String>,
}

impl Service for Hover {
    fn new() -> Self {
        Self::default()
    }

    // changes only through pointer input
    fn listen() {}
}

pub fn key(monitor: &str, item: &str) -> String {
    format!("{monitor}/{item}")
}

pub fn is(key: &str) -> bool {
    Hover::read().key.as_deref() == Some(key)
}

// leaving one item and entering the next can arrive in either order
pub fn set(key: &str, inside: bool) {
    let current = Hover::read().key.clone();

    if inside && current.as_deref() != Some(key) {
        Hover::write().key = Some(key.to_string());
    } else if !inside && current.as_deref() == Some(key) {
        Hover::write().key = None;
    }
}

// whether the pointer is over any item whose key starts this way, on any monitor
pub fn within(item: &str) -> bool {
    Hover::read()
        .key
        .as_deref()
        .and_then(|key| key.split_once('/'))
        .is_some_and(|(_, rest)| rest.starts_with(item))
}
