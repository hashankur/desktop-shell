use amane::{Center, Rectangle, Row, Service, Text, Widget};

use super::parts::{clickable, reveal};
use crate::calendar::{Calendar, agenda};
use crate::clock::Clock;
use crate::hover;
use crate::surface::{Kind, Surface};
use crate::text::shorten;
use crate::theme::{MONO, SANS, Theme, bar};

// more than this many others today reads as this many
const MOST_OTHERS: usize = 9;

/*
 * neue's countdown chip, first on the right: a dot, "in 18m", then "+2" for
 * the rest of today. the event's title waits for the pointer, so the bar
 * stays a readout; a click opens the dashboard, which lists the day. gone
 * when nothing is coming up this week, or the calendar isn't signed in
 */
pub fn view(theme: &Theme, monitor: &str) -> Option<Rectangle> {
    // read first, so the countdown is redrawn every minute
    let clock = Clock::read();
    let (now, offset) = (clock.now(), clock.offset());
    drop(clock);

    let calendar = Calendar::read();
    let events = calendar.events();

    let next = agenda::next(events, now, offset)?;
    let (countdown, others, title) = (
        agenda::glance(next, now, offset),
        agenda::others_today(events, next, now, offset),
        next.title.clone(),
    );
    drop(calendar);

    let key = hover::key(monitor, "event");
    let amount = hover::amount(&key);

    let label_color = hover::mix(&key, theme.on_surface, theme.primary);
    let quiet_color = hover::mix(&key, theme.on_surface_variant, theme.primary);

    // the next event is the one thing in the bar that carries the accent
    let dot = Rectangle::new()
        .width(bar::EVENT_DOT)
        .height(bar::EVENT_DOT)
        .radius(bar::EVENT_DOT / 2.0)
        .fill(theme.primary);

    let mut items: Vec<Box<dyn Widget>> = vec![
        Box::new(dot),
        Box::new(
            Text::new(countdown)
                .font(MONO)
                .size(bar::TEXT)
                .weight(bar::TEXT_WEIGHT)
                .color(label_color),
        ),
    ];

    if others > 0 {
        items.push(Box::new(
            Text::new(format!("+{}", others.min(MOST_OTHERS)))
                .font(MONO)
                .size(bar::TEXT)
                .weight(bar::TEXT_WEIGHT)
                .color(quiet_color),
        ));
    }

    let title = Text::new(shorten(&title, bar::EVENT_CHARS))
        .font(SANS)
        .size(bar::TEXT)
        .weight(bar::TEXT_WEIGHT)
        .color(label_color);

    // the gap is part of the reveal, so it unfolds with the title instead of jumping in
    let title = reveal(title, bar::ITEM_GAP, amount);

    let chip = Row::new(items).gap(bar::ITEM_GAP).align(Center);

    let mut row: Vec<Box<dyn Widget>> = vec![Box::new(chip)];

    if let Some(title) = title {
        row.push(Box::new(title));
    }

    Some(clickable(
        Row::new(row).align(Center),
        key,
        |_| Surface::toggle(Kind::Dashboard),
    ))
}
