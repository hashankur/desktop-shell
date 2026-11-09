use amane::{
    Center, Column, Full, Layer, LayerWindow, Monitor, Parent, Pointer, Rectangle, Row, Service,
    Start, Text, Vertical, Widget, Zone, children,
};

use crate::clock::Clock;
use crate::compositor::{self, Desktop, Space};
use crate::theme::{self, MONO, SANS, Theme, bar};

/*
 * the only persistent chrome: neue's layout, kept from the prototype.
 * the workspace line runs along the top edge; below it the left and right
 * groups take equal shares of the free width, so the clock stays centered
 * whatever they hold
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let spaces = compositor::spaces_on(&monitor.name);

    let row = Row::new(children![left(&theme), center(&theme), right(&theme)])
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
                .child(Column::new(children![line(&spaces, &theme), content])),
        )
}

/*
 * one segment per workspace: active is the bar's accent, occupied reads
 * as quiet text tone, empty recedes further
 */
fn line(spaces: &[Space], theme: &Theme) -> Row {
    let mut segments: Vec<Box<dyn Widget>> = Vec::new();

    for space in spaces {
        let color = if space.active {
            theme.primary
        } else if space.occupied {
            theme::faded(theme.on_surface_variant, 0.45)
        } else {
            theme::faded(theme.outline_variant, 0.6)
        };

        let target = space.clone();

        segments.push(Box::new(
            Rectangle::new()
                .width(Parent)
                .height(bar::LINE)
                .fill(color)
                .cursor(Pointer)
                .on_click(move |_| compositor::switch_to(&target)),
        ));
    }

    Row::new(segments)
        .width(Parent)
        .height(bar::LINE)
        .gap(bar::LINE_GAP)
}

fn left(theme: &Theme) -> Rectangle {
    let desktop = Desktop::read();

    let title = desktop
        .focused()
        .map(|focused| focused.title.clone())
        .unwrap_or_else(|| String::from("Desktop"));

    drop(desktop);

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .align_child(Start, Center)
        .child(
            Text::new(title)
                .font(SANS)
                .size(bar::TEXT)
                .color(theme.on_surface_variant)
                .elide(),
        )
}

fn center(theme: &Theme) -> Text {
    Text::new(Clock::read().readout())
        .font(MONO)
        .size(bar::TEXT)
        .color(theme.on_surface)
}

// media, network, volume and power arrive in the next slice
fn right(_theme: &Theme) -> Rectangle {
    Rectangle::new().width(Parent).height(Parent)
}
