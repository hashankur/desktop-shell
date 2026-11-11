use amane::{Rectangle, Row, Service, Text, children};

use super::parts::clickable;
use crate::clock::Clock;
use crate::hover;
use crate::surface::{Kind, Surface};
use crate::theme::{MONO, SANS, Theme, bar};

/*
 * the time and the date set alike, a step up and in the sans, with the am/pm
 * small and quiet between them. a click opens the dashboard, where the day is
 * laid out in full
 */
pub fn view(theme: &Theme, monitor: &str) -> Rectangle {
    let key = hover::key(monitor, "clock");

    let time_color = hover::mix(&key, theme.on_surface, theme.primary);
    let quiet_color = hover::mix(&key, theme.on_surface_variant, theme.primary);

    let clock = Clock::read();
    let ((time, period), date) = (clock.time(), clock.date());
    drop(clock);

    let large = |text: String| {
        Text::new(text)
            .font(SANS)
            .size(bar::TIME)
            .weight(bar::TIME_WEIGHT)
            .color(time_color)
    };

    let time = Row::new(children![
        large(time),
        Text::new(period)
            .font(MONO)
            .size(bar::SMALL)
            .color(quiet_color),
    ])
    .gap(bar::ITEM_GAP)
    .align(amane::End);

    // bottom-aligned like the am/pm; the date is the time's font and size, so
    // the two share a baseline
    let row = Row::new(children![time, large(date)])
        .gap(bar::DATE_GAP)
        .align(amane::End);

    clickable(row, key, |_| Surface::toggle(Kind::Dashboard))
}
