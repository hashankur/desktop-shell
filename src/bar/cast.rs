use amane::{Center, Rectangle, Row, Service, Text, Widget};

use super::parts::{hoverable, icon, reveal};
use crate::cast::{self, Cast};
use crate::hover;
use crate::icons;
use crate::text::shorten;
use crate::theme::{SANS, Theme, bar};

/*
 * the cast icon while a portal share runs, none otherwise; the apps watching
 * it unfold on hover. it's in the error colour, the one item in the bar meant
 * to be noticed, since what's on screen is going somewhere else. nothing to
 * click: a share is stopped from the app that started it
 */
pub fn view(theme: &Theme, monitor: &str) -> Option<Rectangle> {
    if !Cast::read().sharing() {
        return None;
    }

    let key = hover::key(monitor, "cast");
    let amount = hover::amount(&key);

    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(path) = icons::symbolic("screen-shared", theme.error) {
        items.push(Box::new(icon(path)));
    }

    // a share no app is linked to yet still says what it is
    let viewers = cast::viewers();
    let label = if viewers.is_empty() {
        String::from("sharing")
    } else {
        viewers.join(", ")
    };

    let label = Text::new(shorten(&label, bar::CAST_CHARS))
        .font(SANS)
        .size(bar::TEXT)
        .weight(bar::TEXT_WEIGHT)
        .color(theme.error);

    // the gap is part of the reveal, so it unfolds with the names instead of jumping in
    if let Some(label) = reveal(label, bar::ITEM_GAP, amount) {
        items.push(Box::new(label));
    }

    Some(hoverable(Row::new(items).align(Center), key))
}
