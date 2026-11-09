use std::path::PathBuf;

use amane::{Button, Center, Color, Image, Parent, Pointer, Rectangle, Row, Start, Text, Widget};

use crate::hover;
use crate::theme::{MONO, Theme, bar};

// the small pieces every bar group is built from

// a symbolic icon next to text, already tinted (see icons)
pub fn icon(path: PathBuf) -> Rectangle {
    Rectangle::new()
        .width(bar::ICON)
        .height(bar::ICON)
        .fill(Image::contain(path))
}

// the small group labels: SYS, NET, PWR
pub fn tag(label: &str, theme: &Theme) -> Text {
    Text::new(label)
        .font(MONO)
        .size(bar::TAG)
        .color(theme.on_surface_variant)
}

// the one place the bar draws lines: between groups
pub fn rule(theme: &Theme) -> Rectangle {
    Rectangle::new()
        .width(bar::RULE_WIDTH)
        .height(bar::RULE_HEIGHT)
        .fill(theme.outline_variant)
}

// an item that acts on click: pointer cursor, and its text and icon turn primary under the pointer
pub fn clickable(row: Row, key: String, action: impl Fn(Button) + 'static) -> Rectangle {
    // a rectangle can't fit its child, but a row of fixed items knows its width
    let width = Widget::width(&row);

    // the bar's full height, so the pointer doesn't have to find a 16px line
    Rectangle::new()
        .width(width)
        .height(Parent)
        .align_child(Start, Center)
        .child(row)
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(action)
}

pub fn hovered_color(key: &str, theme: &Theme) -> Color {
    if hover::is(key) {
        theme.primary
    } else {
        theme.on_surface_variant
    }
}
