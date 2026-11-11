use amane::{Column, Service, Widget};

use super::{block, label, small, tinted_line};
use crate::calendar::{Calendar, agenda};
use crate::clock::Clock;
use crate::theme::Theme;

/*
 * today from the calendar: when, what, and for the next one how soon. the
 * next is the block's accent; what's over has gone quiet. none until the
 * calendar is signed in. an empty day says so, so a quiet day doesn't
 * read as a broken calendar
 */
pub fn view(theme: &Theme) -> Option<Column> {
    let clock = Clock::read();
    let (now, offset) = (clock.now(), clock.offset());
    drop(clock);

    let calendar = Calendar::read();

    if !calendar.signed_in() {
        return None;
    }

    let events = calendar.events();
    let next = agenda::next(events, now, offset);

    let lines: Vec<Box<dyn Widget>> = agenda::today(events, now, offset)
        .into_iter()
        .map(|event| {
            let is_next = next == Some(event);

            let colors = if is_next {
                (theme.primary, theme.primary, theme.primary)
            } else if event.end <= now {
                (theme.outline, theme.outline, theme.outline)
            } else {
                (theme.on_surface_variant, theme.on_surface, theme.on_surface_variant)
            };

            let trailing = if is_next {
                agenda::countdown(event, now, offset)
            } else {
                String::new()
            };

            Box::new(tinted_line(
                &agenda::start_time(event, now, offset),
                &event.title,
                &trailing,
                colors,
            )) as Box<dyn Widget>
        })
        .collect();

    drop(calendar);

    let lines = if lines.is_empty() {
        vec![Box::new(small("nothing on", theme.on_surface_variant)) as Box<dyn Widget>]
    } else {
        lines
    };

    Some(block(Box::new(label("today", theme)), lines))
}
