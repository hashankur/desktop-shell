mod agenda;
mod browse;
mod calendar;
mod expand;
mod month;
mod note;
mod notes;
mod parts;
mod playing;
mod task;

use amane::{
    Center, Column, Key, Monitor, Padding, Parent, Rectangle, Row, Service, Size, Start, Text,
    Weight, Widget,
};

use crate::clock::Clock;
use crate::theme::{SANS, Theme, bar, dash, grid, size, space};
use parts::{small, spacer};

// what the dashboard looks up when it opens, and what it opens on: this month, every sender folded
pub fn refresh() {
    crate::calendar::refresh_if_stale();
    crate::tasks::refresh_if_stale();
    browse::reset();
    expand::reset();
}

pub fn key(key: Key) {
    browse::key(key);
}

/*
 * three columns of four on the grid, top left to top right: the day as the
 * one large element over the month and what's on, then what is playing
 * around its cover, then the notifications. the cover starts level with
 * the month, under the day; the notifications start level with the day's
 * letters
 */
pub fn view(theme: &Theme, monitor: &Monitor) -> Rectangle {
    let width = grid::span(dash::COLUMN, monitor.width as f32);

    // the surface sits under the bar, with the grid's margin all round
    let room = monitor.height as f32 - bar::HEIGHT - 2.0 * grid::MARGIN - dash::BESIDE;

    let art = dash::ART.min(width);

    let heading = heading(theme, width);

    // the cover starts level with the month's grid, under the day
    let below_heading = fixed_height(&heading);

    let playing = playing::view(theme, &monitor.name, art)
        .map(|playing| Column::new(vec![Box::new(spacer(below_heading)) as Box<dyn Widget>, Box::new(playing)]).width(art));

    let notes = notes::view(theme, &monitor.name, width, room)
        .map(|notes| Column::new(vec![Box::new(spacer(dash::BESIDE)) as Box<dyn Widget>, Box::new(notes)]).width(width));

    let row = Row::new(vec![
        Box::new(block(Some(calendar(theme, monitor, heading, width)), width)) as Box<dyn Widget>,
        Box::new(block(playing, width)),
        Box::new(block(notes, width)),
    ])
    .gap(grid::GUTTER)
    .align(Start);

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(Padding::from(grid::MARGIN))
        .align_child(Start, Start)
        .child(row)
}

// the day as the one large element, then the month and week under it, over the month's grid
fn heading(theme: &Theme, width: f32) -> Column {
    let clock = Clock::read();
    let (days, day, month) = (clock.days(), clock.weekday_and_day(), clock.month_and_year());
    drop(clock);

    let (_, week) = calendar::iso_week(days);

    Column::new(vec![
        Box::new(
            Text::new(day)
                .font(SANS)
                .weight(Weight::Light)
                .size(size::LG)
                .color(theme.on_surface),
        ) as Box<dyn Widget>,
        Box::new(spacer(space::SM)),
        Box::new(small(format!("{month} · week {week}"), theme.on_surface_variant)),
        Box::new(spacer(space::LG)),
    ])
    .width(width)
}

// the left column: the heading, the month's grid and the agenda under it
fn calendar(theme: &Theme, monitor: &Monitor, heading: Column, width: f32) -> Column {
    let mut items: Vec<Box<dyn Widget>> = vec![
        Box::new(heading),
        Box::new(month::view(theme, &monitor.name, width)),
    ];

    if let Some(agenda) = agenda::view(theme, &monitor.name, width) {
        items.push(Box::new(spacer(space::LG)));
        items.push(Box::new(agenda));
    }

    Column::new(items).width(width)
}

// how tall a column is, when it knows
fn fixed_height(column: &Column) -> f32 {
    match Widget::height(column) {
        Size::Fixed(height) => height,
        Size::Parent => 0.0,
    }
}

/*
 * one column's place, its content centred across it. a click anywhere on
 * the surface closes it through the scrim below, so the content takes its
 * own clicks and does nothing with them; the space under it still closes
 */
fn block(content: Option<Column>, width: f32) -> Rectangle {
    let Some(content) = content else {
        return Rectangle::new().width(width).height(0.0);
    };

    let height = fixed_height(&content);

    let inner = match Widget::width(&content) {
        Size::Fixed(inner) => inner,
        Size::Parent => width,
    };

    Rectangle::new()
        .width(width)
        .height(height)
        .align_child(Center, Start)
        .child(
            Rectangle::new()
                .width(inner)
                .height(height)
                .on_click(|_| {})
                .child(content),
        )
}
