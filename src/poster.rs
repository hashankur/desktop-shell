use amane::{
    Battery, Column, Full, Layer, LayerWindow, Monitor, Network, Padding, Parent, Rectangle, Row,
    Service, Text, Weight, Widget, Zone, children,
};

use crate::clock::Clock;
use crate::compositor;
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

    let shown = is_empty(&monitor.name);

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
                .padding(Padding {
                    top: grid::MARGIN,
                    right: grid::MARGIN,
                    bottom: grid::MARGIN,
                    left: grid::MARGIN,
                })
                .child(
                    Row::new(children![left(&theme), side(&theme, monitor.width)])
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

fn left(theme: &Theme) -> Column {
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
    let free = screen_width as f32 - 2.0 * grid::MARGIN - (grid::COLUMNS - 1) as f32 * grid::GUTTER;
    let column = free / grid::COLUMNS as f32;
    let width = 4.0 * column + 3.0 * grid::GUTTER;

    let mut blocks: Vec<Box<dyn Widget>> = Vec::new();

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
