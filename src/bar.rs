mod media;
mod notifications;
mod net;
mod parts;
mod power;
mod system;
mod window;
mod workspaces;

use amane::{
    Center, Column, End, Full, Layer, LayerWindow, Monitor, Parent, Rectangle, Row, Service,
    Size, Start, Text, Vertical, Widget, Zone, children,
};

use crate::clock::Clock;
use crate::compositor;
use crate::lock;
use crate::theme::{self, MONO, Theme, bar};
use parts::rule;

/*
 * the only persistent chrome: neue's layout, kept from the prototype.
 * the workspace line runs along the top edge; below it the left and right
 * groups take equal shares of the free width, so the clock stays centered
 * whatever they hold. each group lives in its own module; this file only
 * places them
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let spaces = compositor::spaces_on(&monitor.name);

    let row = Row::new(children![
        left(&theme),
        center(&theme, &monitor.name),
        right(&theme, &monitor.name)
    ])
    .width(Parent)
    .height(Parent)
    .gap(bar::GROUP_GAP)
    .align(Center);

    let content = Rectangle::new()
        .width(Parent)
        .height(bar::HEIGHT - bar::LINE)
        .padding(amane::Padding {
            top: 0.0,
            right: bar::EDGE,
            bottom: 0.0,
            left: bar::EDGE,
        })
        .child(row);

    LayerWindow::new()
        .width(Full)
        .height(bar::HEIGHT)
        .anchor_vertical(Vertical::Top)
        .layer(Layer::Top)
        .space(Zone::Reserve)
        .namespace("yohaku-bar")
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .fill(theme.surface)
                // leaves first when the session locks, and comes back last
                .opacity(lock::curtain_items())
                .child(Column::new(children![
                    workspaces::view(&spaces, &theme),
                    content
                ])),
        )
}

// SYS and its rings, a rule, then the focused window in what's left
fn left(theme: &Theme) -> Rectangle {
    let row = Row::new(children![
        system::view(theme),
        rule(theme),
        window::view(theme),
    ])
    .width(Parent)
    .height(Parent)
    .gap(bar::GROUP_GAP)
    .align(Center);

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .align_child(Start, Center)
        .child(row)
}

/*
 * the clock stays dead center: whatever sits beside it, the bell and its rule
 * now, the next event later, gets a side of the same width on each side
 */
fn center(theme: &Theme, monitor: &str) -> Row {
    let clock = Text::new(Clock::read().readout())
        .font(MONO)
        .size(bar::TEXT)
        .color(theme.on_surface);

    let after = notifications::view(theme, monitor).map(|bell| {
        Row::new(children![rule(theme), bell])
            .gap(bar::GROUP_GAP)
            .align(Center)
    });

    let side = after.as_ref().map_or(0.0, |row| match Widget::width(row) {
        Size::Fixed(width) => width,
        Size::Parent => 0.0,
    });

    let before = Rectangle::new().width(side).height(Parent);

    let mut after_side = Rectangle::new()
        .width(side)
        .height(Parent)
        .align_child(Start, Center);

    if let Some(row) = after {
        after_side = after_side.child(row);
    }

    Row::new(children![before, clock, after_side])
        .height(Parent)
        .gap(bar::GROUP_GAP)
        .align(Center)
}

/*
 * media, then NET with wifi and volume, then PWR with the battery and the
 * power icon, split by rules; media and its rule leave when spotify isn't open
 */
fn right(theme: &Theme, monitor: &str) -> Rectangle {
    let mut groups: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(media) = media::view(theme, monitor) {
        groups.push(Box::new(media));
        groups.push(Box::new(rule(theme)));
    }

    groups.push(Box::new(net::view(theme, monitor)));
    groups.push(Box::new(rule(theme)));
    groups.push(Box::new(power::view(theme, monitor)));

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .align_child(End, Center)
        .child(Row::new(groups).gap(bar::GROUP_GAP).align(Center))
}
