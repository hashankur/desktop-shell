use amane::{Column, Parent, Rectangle, Row, Service, Text, Weight, Widget, children};

use crate::clock::Clock;
use crate::theme::{MONO, SANS, Theme, lock, space};

/*
 * the time large and tight, with the am/pm small after it on the baseline,
 * and the date under it in the mono, uppercase and quiet, like the bar's.
 * a text's box runs from above its ascent to below its descent, which for
 * a number this size leaves a lot of empty room, so the pieces are lined up
 * by their ink: the left edges flush, the am/pm on the time's baseline and
 * the date a set distance below it
 */
pub fn view(theme: &Theme) -> Column {
    let clock = Clock::read();
    let ((time, period), day) = (clock.time(), clock.day());
    drop(clock);

    let time = Row::new(children![
        Text::new(time)
            .font(SANS)
            .weight(Weight::Light)
            .size(lock::TIME)
            .color(theme.on_surface)
            .tight(),
        nudged(
            Text::new(period)
                .font(MONO)
                .size(lock::PERIOD)
                .color(theme.on_surface_variant),
            -lock::period_lift(),
        ),
    ])
    .gap(space::MD)
    .align(amane::End);

    let date = Text::new(day.to_uppercase())
        .font(MONO)
        .size(lock::DATE)
        .color(theme.on_surface_variant)
        .tight();

    Column::new(children![time, nudged(date, -lock::date_rise())])
        .width(Parent)
        .gap(space::LG)
}

// drawn `down` pixels lower than its place, without moving anything around it
fn nudged(text: Text, down: f32) -> Rectangle {
    Rectangle::new()
        .width(text.width())
        .height(text.height())
        .translate(0.0, down)
        .child(text)
}
