mod calendar;
mod events;
mod notes;
mod playing;
mod system;

use std::process::Command;
use std::thread;

use amane::{
    Button, Center, Column, Monitor, Padding, Parent, Pointer, Rectangle, Row, Service, Size,
    Start, Text, Weight, Widget, children,
};

use crate::clock::Clock;
use crate::hover;
use crate::theme::{MONO, SANS, Theme, dash, grid, size, space};

/*
 * what the dashboard looks up when it opens, things too slow to read in a
 * view. empty until the first look, and a failed look leaves it empty
 */
#[derive(Default)]
pub struct Dashboard {
    // how full the filesystem holding home is, in percent
    disk: Option<u8>,
}

impl Service for Dashboard {
    fn new() -> Self {
        Self::default()
    }

    // only changes when the dashboard opens
    fn listen() {}
}

/*
 * asks df off the ui thread, each time the dashboard opens. it asks about
 * home, not /: with an impermanent root, / is a tmpfs that always reads
 * empty, and home is where the space actually runs out
 */
pub fn refresh() {
    crate::calendar::refresh_if_stale();

    thread::spawn(|| {
        let home = std::env::var_os("HOME").unwrap_or_else(|| "/".into());

        let disk = Command::new("df")
            .arg("-P")
            .arg(home)
            .output()
            .ok()
            .and_then(|output| disk_percent(&String::from_utf8_lossy(&output.stdout)));

        if Dashboard::read().disk != disk {
            Dashboard::write().disk = disk;
        }
    });
}

// `df -P` prints a header, then one line whose fifth field is like "41%"
fn disk_percent(df: &str) -> Option<u8> {
    df.lines()
        .nth(1)?
        .split_whitespace()
        .nth(4)?
        .trim_end_matches('%')
        .parse()
        .ok()
}

/*
 * top left, on the grid's first four columns, as the design table says:
 * the day as the one large element, the month under it, then what is
 * today's events, what is playing, the notifications, and the machine,
 * each a small block
 */
pub fn view(theme: &Theme, monitor: &Monitor) -> Rectangle {
    let width = grid::span(dash::COLUMNS, monitor.width as f32);

    let clock = Clock::read();
    let (days, day, month) = (
        clock.days(),
        clock.weekday_and_day(),
        clock.month_and_year(),
    );
    drop(clock);

    let (_, week) = calendar::iso_week(days);

    let mut items: Vec<Box<dyn Widget>> = vec![
        Box::new(
            Text::new(day)
                .font(SANS)
                .weight(Weight::Light)
                .size(size::LG)
                .color(theme.on_surface),
        ),
        Box::new(spacer(space::SM)),
        Box::new(small(
            format!("{month} · week {week}"),
            theme.on_surface_variant,
        )),
        Box::new(spacer(space::LG)),
        Box::new(calendar::view(days, theme)),
    ];

    let blocks = [
        events::view(theme),
        playing::view(theme, &monitor.name, width),
        notes::view(theme, &monitor.name),
        Some(system::view(theme)),
    ];

    for block in blocks.into_iter().flatten() {
        items.push(Box::new(spacer(space::LG)));
        items.push(Box::new(block));
    }

    let column = Column::new(items).width(width);

    let height = match Widget::height(&column) {
        Size::Fixed(height) => height,
        Size::Parent => 0.0,
    };

    /*
     * a click anywhere on the surface closes it through the scrim below, so
     * the block takes its own clicks and does nothing with them
     */
    let block = Rectangle::new()
        .width(width)
        .height(height)
        .on_click(|_| {})
        .child(column);

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(Padding::from(grid::MARGIN))
        .align_child(Start, Start)
        .child(block)
}

fn spacer(height: f32) -> Rectangle {
    Rectangle::new().width(Parent).height(height)
}

fn small(text: impl Into<String>, color: amane::Color) -> Text {
    Text::new(text).font(MONO).size(size::SM).color(color)
}

// a block's name, in the small capitals every label uses
fn label(text: &str, theme: &Theme) -> Text {
    small(text.to_uppercase(), theme.on_surface_variant)
}

// a block: its label, then its lines close under it
fn block(head: Box<dyn Widget>, lines: Vec<Box<dyn Widget>>) -> Column {
    let mut items = vec![head];

    items.extend(lines);

    Column::new(items).width(Parent).gap(space::XS)
}

fn line_height() -> f32 {
    size::MD * 1.5
}

/*
 * a line of a block: something small in the left column, a name, and
 * something small at the end. hovered, all of it eases to primary;
 * `hovered` is how far, from 0 to 1
 */
fn line(lead: &str, name: &str, trailing: &str, theme: &Theme, hovered: f32) -> Row {
    let ease = |rest: amane::Color| <amane::Color as amane::Blend>::blend(rest, theme.primary, hovered);

    let colors = (
        ease(theme.on_surface_variant),
        ease(theme.on_surface),
        ease(theme.on_surface_variant),
    );

    tinted_line(lead, name, trailing, colors)
}

// the same line in colors of its own: the lead, the name, and the end
fn tinted_line(
    lead: &str,
    name: &str,
    trailing: &str,
    (lead_color, name_color, trailing_color): (amane::Color, amane::Color, amane::Color),
) -> Row {
    let lead = Rectangle::new()
        .width(dash::LEAD)
        .height(line_height())
        .align_child(Start, Center)
        .child(small(lead, lead_color));

    let name = Text::new(name)
        .font(SANS)
        .size(size::MD)
        .color(name_color)
        .elide();

    Row::new(children![lead, name, small(trailing, trailing_color)])
        .width(Parent)
        .gap(space::MD)
        .align(Center)
}

// a line that acts on click, under its own hover key
fn clickable(row: Row, key: String, action: impl Fn(Button) + 'static) -> Rectangle {
    Rectangle::new()
        .width(Parent)
        .height(line_height())
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(action)
        .align_child(Start, Center)
        .child(row)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_the_disk_from_df() {
        let df = "Filesystem     1024-blocks      Used Available Capacity Mounted on\n\
                  /dev/nvme0n1p2   488245288 199872332 286418920      42% /\n";

        assert_eq!(disk_percent(df), Some(42));
        assert_eq!(disk_percent("Filesystem 1024-blocks\n"), None);
        assert_eq!(disk_percent(""), None);
    }
}
