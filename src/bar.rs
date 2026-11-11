mod battery;
mod clock;
mod event;
mod media;
mod notifications;
mod net;
mod parts;
mod system;
mod window;
mod workspaces;

use amane::{
    Center, Column, End, Full, Layer, LayerWindow, Monitor, Parent, Rectangle, Row, Size, Start,
    Vertical, Widget, Zone, children,
};

use crate::compositor;
use crate::lock;
use crate::theme::{self, SCRIM_OPACITY, Theme, bar};

/*
 * the only persistent chrome. the workspace line runs along the top edge;
 * below it the left and right groups take equal shares of the free width,
 * so the clock stays centered whatever they hold. groups are set apart by
 * space alone, no rules or labels, and the bar sits on the surfaces' scrim.
 * each group lives in its own module; this file only places them
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let spaces = compositor::spaces_on(&monitor.name);

    let row = Row::new(children![
        left(&theme, &monitor.name),
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
                // the same scrim a surface lays over the windows
                .fill(theme::faded(theme.scrim, SCRIM_OPACITY))
                // leaves first when the session locks, and comes back last
                .opacity(lock::curtain_items())
                .child(Column::new(children![
                    workspaces::view(&spaces, &theme, &monitor.name),
                    content
                ])),
        )
}

// the stats rings, then the focused window in what's left
fn left(theme: &Theme, monitor: &str) -> Rectangle {
    let row = Row::new(children![system::view(theme, monitor), window::view(theme)])
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
 * the clock stays dead center: the next event before it and the bell after
 * it each get a side as wide as the wider of the two
 */
fn center(theme: &Theme, monitor: &str) -> Row {
    let before = event::view(theme, monitor);
    let after = notifications::view(theme, monitor);

    let width = |item: &Option<Rectangle>| {
        item.as_ref().map_or(0.0, |item| match Widget::width(item) {
            Size::Fixed(width) => width,
            Size::Parent => 0.0,
        })
    };

    let side = width(&before).max(width(&after));

    let mut before_side = Rectangle::new()
        .width(side)
        .height(Parent)
        .align_child(End, Center);

    if let Some(event) = before {
        before_side = before_side.child(event);
    }

    let mut after_side = Rectangle::new()
        .width(side)
        .height(Parent)
        .align_child(Start, Center);

    if let Some(bell) = after {
        after_side = after_side.child(bell);
    }

    Row::new(children![before_side, clock::view(theme, monitor), after_side])
        .height(Parent)
        .gap(bar::GROUP_GAP)
        .align(Center)
}

/*
 * media, then the connection, then the battery. media leaves when spotify
 * isn't open and the battery on a machine without one; power is a launcher
 * command and a keybind, not a button, and the volume shows in the osd
 */
fn right(theme: &Theme, monitor: &str) -> Rectangle {
    let mut groups: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(media) = media::view(theme, monitor) {
        groups.push(Box::new(media));
    }

    groups.push(Box::new(net::view(theme, monitor)));

    if let Some(battery) = battery::view(theme, monitor) {
        groups.push(Box::new(battery));
    }

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .align_child(End, Center)
        .child(Row::new(groups).gap(bar::GROUP_GAP).align(Center))
}
