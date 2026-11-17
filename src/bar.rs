mod battery;
mod cast;
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
    Center, Column, End, Full, Layer, LayerWindow, Monitor, Parent, Rectangle, Row, Start,
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
        clock::view(&theme, &monitor.name),
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
 * the next event, media, screen sharing, the connection, the battery, then
 * the bell in the corner the toasts come from. the event leaves when nothing
 * is coming up, media when spotify isn't open, sharing when nothing is being
 * shared, the battery on a machine without one and
 * the bell while another daemon holds the notifications; power is a launcher
 * command and a keybind, not a button, and the volume shows in the osd
 */
fn right(theme: &Theme, monitor: &str) -> Rectangle {
    let mut groups: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(event) = event::view(theme, monitor) {
        groups.push(Box::new(event));
    }

    if let Some(media) = media::view(theme, monitor) {
        groups.push(Box::new(media));
    }

    if let Some(cast) = cast::view(theme, monitor) {
        groups.push(Box::new(cast));
    }

    groups.push(Box::new(net::view(theme, monitor)));

    if let Some(battery) = battery::view(theme, monitor) {
        groups.push(Box::new(battery));
    }

    if let Some(bell) = notifications::view(theme, monitor) {
        groups.push(Box::new(bell));
    }

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .align_child(End, Center)
        .child(Row::new(groups).gap(bar::GROUP_GAP).align(Center))
}
