use amane::{
    Arc, Canvas, Cap, Center, Column, Cpu, Full, Layer, LayerWindow, Memory, Monitor, Parent,
    Pointer, Rectangle, Row, Service, Shape, Start, Text, Vertical, Widget, Zone, children, shapes,
};

use crate::clock::Clock;
use crate::compositor::{self, Desktop, Space};
use crate::stats::Sensors;
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

// SYS and its rings, a rule, then the focused window's title in what's left
fn left(theme: &Theme) -> Rectangle {
    let desktop = Desktop::read();

    let title = desktop
        .focused()
        .map(|focused| focused.title.clone())
        .unwrap_or_else(|| String::from("Desktop"));

    drop(desktop);

    let row = Row::new(children![
        tag("SYS", theme),
        rings(theme),
        rule(theme),
        Text::new(title)
            .font(SANS)
            .size(bar::TEXT)
            .color(theme.on_surface_variant)
            .elide(),
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
 * cpu, memory, gpu and cpu temperature as neue had them; a sensor this
 * machine doesn't have leaves its ring out instead of showing zero
 */
fn rings(theme: &Theme) -> Row {
    let cpu = f32::from(Cpu::read().percent()) / 100.0;
    let memory = f32::from(Memory::read().percent()) / 100.0;

    let sensors = Sensors::read();
    let (gpu, temp) = (sensors.gpu(), sensors.temp());
    drop(sensors);

    let values = [Some(cpu), Some(memory), gpu, temp];

    let rings: Vec<Box<dyn Widget>> = values
        .into_iter()
        .flatten()
        .map(|value| Box::new(ring(value, theme)) as Box<dyn Widget>)
        .collect();

    Row::new(rings).gap(bar::ITEM_GAP).align(Center)
}

// a track with the value over it, from the top, clockwise
fn ring(value: f32, theme: &Theme) -> Canvas {
    let middle = bar::RING / 2.0;

    // the stroke is centered on the radius, so half of it sits outside
    let radius = middle - bar::RING_STROKE / 2.0;

    Canvas::new().width(bar::RING).height(bar::RING).shapes(shapes![
        Arc::new()
            .center(middle, middle)
            .radius(radius)
            .stroke(bar::RING_STROKE, theme.outline_variant),
        Arc::new()
            .center(middle, middle)
            .radius(radius)
            .sweep(360.0 * value.clamp(0.0, 1.0))
            .stroke(bar::RING_STROKE, theme.primary)
            .cap(Cap::Round),
    ])
}

// the small group labels: SYS, NET, PWR
fn tag(label: &str, theme: &Theme) -> Text {
    Text::new(label)
        .font(MONO)
        .size(bar::TAG)
        .color(theme.on_surface_variant)
}

// the one place the bar draws lines: between groups
fn rule(theme: &Theme) -> Rectangle {
    Rectangle::new()
        .width(bar::RULE_WIDTH)
        .height(bar::RULE_HEIGHT)
        .fill(theme.outline_variant)
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
