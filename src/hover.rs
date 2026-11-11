use std::collections::HashMap;
use std::time::Duration;

use amane::{Animation, Blend, Color, Service};

use crate::theme::timing;

/*
 * which item the pointer is over; hover feedback is a clickable item's text
 * and icon turning primary, never a fill, or an item spelling out more of
 * what it shows. keys carry the monitor name,
 * so the same item on another bar doesn't light up with it.
 *
 * each item also eases from 0 to 1 as the pointer arrives and back as it
 * leaves, so colours blend and details unfold instead of snapping
 */
#[derive(Default)]
pub struct Hover {
    key: Option<String>,
    amounts: HashMap<String, Animation>,
}

impl Service for Hover {
    fn new() -> Self {
        Self::default()
    }

    // changes only through pointer input
    fn listen() {}
}

impl Hover {
    fn ease(&mut self, key: &str, target: f32) {
        self.amounts
            .entry(key.to_string())
            .or_insert_with(|| Animation::new(0.0).duration(Duration::from_secs_f32(timing::HOVER)))
            .to(target);
    }
}

pub fn key(monitor: &str, item: &str) -> String {
    format!("{monitor}/{item}")
}

/*
 * how far the item is into its hover, 0 at rest to 1 under the pointer.
 * read in a view, so the window keeps drawing until it has settled
 */
pub fn amount(key: &str) -> f32 {
    Hover::read().amounts.get(key).map_or(0.0, Animation::value)
}

// the item's colour this frame, on its way between resting and hovered
pub fn mix(key: &str, rest: Color, hovered: Color) -> Color {
    Color::blend(rest, hovered, amount(key))
}

/*
 * for rows lit when selected or hovered: the keyboard's selection lights a
 * row at once, the pointer eases into it
 */
pub fn mix_selected(key: &str, selected: bool, rest: Color, hovered: Color) -> Color {
    if selected {
        return hovered;
    }

    mix(key, rest, hovered)
}

// leaving one item and entering the next can arrive in either order
pub fn set(key: &str, inside: bool) {
    let current = Hover::read().key.clone();

    if inside && current.as_deref() != Some(key) {
        let mut hover = Hover::write();

        if let Some(previous) = current {
            hover.ease(&previous, 0.0);
        }

        hover.ease(key, 1.0);
        hover.key = Some(key.to_string());
    } else if !inside && current.as_deref() == Some(key) {
        let mut hover = Hover::write();

        hover.ease(key, 0.0);
        hover.key = None;
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
