use amane::{Center, Parent, Row, Service, Text, Widget};

use super::parts::icon;
use crate::compositor::Desktop;
use crate::icons;
use crate::theme::{SANS, Theme, bar};

// the focused app's symbolic icon, when it has one, and its title in the rest of the width
pub fn view(theme: &Theme) -> Row {
    let desktop = Desktop::read();

    let (app_id, title) = match desktop.focused() {
        Some(focused) => (focused.app_id.clone(), focused.title.clone()),
        None => (String::new(), String::from("Desktop")),
    };

    drop(desktop);

    let color = theme.on_surface_variant;

    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(path) = icons::app(&app_id, color) {
        items.push(Box::new(icon(path)));
    }

    items.push(Box::new(
        Text::new(title)
            .font(SANS)
            .size(bar::TEXT)
            .color(color)
            .elide(),
    ));

    Row::new(items)
        .width(Parent)
        .gap(bar::ITEM_GAP)
        .align(Center)
}
