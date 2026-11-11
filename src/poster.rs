use amane::{
    Battery, Column, Full, Layer, LayerWindow, Monitor, Network, Padding, Parent, Rectangle, Row,
    Service, Text, Weight, Widget, Zone, children,
};

use crate::calendar::{Calendar, agenda};
use crate::clock::Clock;
use crate::compositor;
use crate::lock;
use crate::motion;
use crate::spotify::Spotify;
use crate::theme::{self, MONO, SANS, Theme, grid, size, space};

/*
 * what an empty workspace shows: the time and date large at the top left,
 * and a quiet column on the grid's last four columns. the window sits on
 * the bottom layer, below every window, and exists only so there is something
 * to look at; it never takes a click. it is only shown while the monitor's
 * active workspace has no windows
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let empty = is_empty(&monitor.name);

    // it fades and slides in and out with the workspace; the window stays shown until it has left
    let motion = motion::presence(&format!("poster/{}", monitor.name), empty);

    let shown = empty || motion.moving;

    LayerWindow::new()
        .width(Full)
        .height(Full)
        .layer(Layer::Bottom)
        // the bar's own space is already taken
        .space(Zone::Respect)
        .namespace("yohaku-poster")
        .click_through()
        .visible(shown)
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                // it also leaves with the bar when the session locks
                .opacity(motion.content * lock::curtain_items())
                .translate(0.0, motion.shift)
                .padding(Padding {
                    top: grid::MARGIN,
                    right: grid::MARGIN,
                    bottom: grid::MARGIN,
                    left: grid::MARGIN,
                })
                .child(
                    Row::new(children![time_and_date(&theme), side(&theme, monitor.width)])
                        .width(Parent)
                        .height(Parent)
                        .gap(grid::GUTTER),
                ),
        )
}

// no workspace known, as with no compositor, counts as occupied so nothing is drawn over it
fn is_empty(output: &str) -> bool {
    compositor::spaces_on(output)
        .iter()
        .find(|space| space.active)
        .is_some_and(|space| !space.occupied)
}

// the time and date, large; the lock screen shows the same block
pub fn time_and_date(theme: &Theme) -> Column {
    let clock = Clock::read();
    let (time, day) = (clock.hm(), clock.day());
    drop(clock);

    Column::new(children![
        Text::new(time)
            .font(SANS)
            .weight(Weight::Light)
            .size(size::POSTER)
            .color(theme.on_surface),
        Text::new(day)
            .font(SANS)
            .size(size::MD)
            .color(theme.on_surface),
    ])
    .width(Parent)
    .gap(space::LG)
}

// four grid columns wide, flush with the right margin
fn side(theme: &Theme, screen_width: u32) -> Column {
    let width = grid::span(4, screen_width as f32);

    let mut blocks: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(today) = today(theme) {
        blocks.push(Box::new(today));
    }

    if let Some(playing) = playing(theme) {
        blocks.push(Box::new(playing));
    }

    if let Some(system) = system(theme) {
        blocks.push(Box::new(system));
    }

    Column::new(blocks)
        .width(width)
        // lines up with the time's cap height rather than its box
        .gap(space::LG)
}

fn label(text: &str, theme: &Theme) -> Text {
    Text::new(text.to_uppercase())
        .font(MONO)
        .size(size::SM)
        .color(theme.on_surface_variant)
}

fn small(text: impl Into<String>, theme: &Theme) -> Text {
    Text::new(text)
        .font(MONO)
        .size(size::SM)
        .color(theme.on_surface_variant)
        .elide()
}

// what's still to come today, the next one in the accent; none when the day is done
fn today(theme: &Theme) -> Option<Column> {
    let clock = Clock::read();
    let (now, offset) = (clock.now(), clock.offset());
    drop(clock);

    let calendar = Calendar::read();
    let events = calendar.events();
    let next = agenda::next(events, now, offset);

    let mut lines: Vec<Box<dyn Widget>> = agenda::today(events, now, offset)
        .into_iter()
        .filter(|event| event.end > now)
        .map(|event| {
            let (time_color, title_color) = if next == Some(event) {
                (theme.primary, theme.primary)
            } else {
                (theme.on_surface_variant, theme.on_surface)
            };

            let row = Row::new(children![
                Text::new(agenda::start_time(event, now, offset))
                    .font(MONO)
                    .size(size::SM)
                    .color(time_color),
                Text::new(event.title.clone())
                    .font(SANS)
                    .size(size::MD)
                    .color(title_color)
                    .elide(),
            ])
            .width(Parent)
            .gap(space::MD)
            .align(amane::Center);

            Box::new(row) as Box<dyn Widget>
        })
        .collect();

    drop(calendar);

    if lines.is_empty() {
        return None;
    }

    lines.insert(0, Box::new(label("today", theme)));

    Some(Column::new(lines).width(Parent).gap(space::SM))
}

// spotify's track, none while it isn't open
fn playing(theme: &Theme) -> Option<Column> {
    let spotify = Spotify::read();
    let track = spotify.track()?.clone();
    drop(spotify);

    let mut lines: Vec<Box<dyn Widget>> = vec![
        Box::new(label("playing", theme)),
        Box::new(
            Text::new(track.title)
                .font(SANS)
                .size(size::MD)
                .color(theme.on_surface)
                .elide(),
        ),
    ];

    if !track.artist.is_empty() {
        lines.push(Box::new(small(track.artist, theme)));
    }

    Some(Column::new(lines).width(Parent).gap(space::SM))
}

// the battery and the connection, whichever of them this machine has
fn system(theme: &Theme) -> Option<Column> {
    let battery = Battery::read();
    let power = battery.present().then(|| format!("{}%", battery.percent()));
    drop(battery);

    let network = Network::read();
    let net = (!network.ssid().is_empty()).then(|| network.ssid().to_string());
    drop(network);

    let mut lines: Vec<Box<dyn Widget>> = Vec::new();

    for line in [power, net].into_iter().flatten() {
        lines.push(Box::new(small(line, theme)));
    }

    if lines.is_empty() {
        return None;
    }

    lines.insert(0, Box::new(label("system", theme)));

    Some(Column::new(lines).width(Parent).gap(space::SM))
}
