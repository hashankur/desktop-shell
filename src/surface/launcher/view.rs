use amane::{
    Center, Color, Column, End, Monitor, Padding, Parent, Pointer, Rectangle, Row, Service, Start,
    Text, Weight, Widget, children,
};

use super::{Entry, Group, Launcher, groups, launch};
use crate::hover;
use crate::text::shorten;
use crate::theme::{MONO, SANS, Theme, grid, list, size, space};

/*
 * bottom left, on the grid's first four columns, as the design table says.
 * the list has a fixed height, so the query above it stays where it is
 * however many results there are
 */
pub fn view(theme: &Theme, monitor: &Monitor) -> Rectangle {
    let launcher = Launcher::read();
    let (query, selected) = (launcher.query.clone(), launcher.selected);
    drop(launcher);

    let width = grid::span(4, monitor.width as f32);

    let query_height = size::LG * 1.1;
    let list_height = size::MD * 1.5 * list::ROWS + space::MD * 2.0;
    let meta_height = size::SM * 1.5;

    let total = query_height + space::LG + list_height + space::MD + meta_height;

    let column = Column::new(children![
        query_line(&query, theme, query_height),
        spacer(space::LG),
        results(&query, selected, theme, &monitor.name, list_height),
        spacer(space::MD),
        meta(theme, meta_height),
    ])
    .width(width);

    /*
     * a click anywhere on the surface closes it through the scrim below, so
     * the block takes its own clicks and does nothing with them
     */
    let block = Rectangle::new()
        .width(width)
        .height(total)
        .on_click(|_| {})
        .child(column);

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(Padding {
            top: grid::MARGIN,
            right: grid::MARGIN,
            bottom: grid::MARGIN,
            left: grid::MARGIN,
        })
        .align_child(Start, End)
        .child(block)
}

fn spacer(height: f32) -> Rectangle {
    Rectangle::new().width(Parent).height(height)
}

// the one large element: what is typed, with a caret, or the ghost word before anything is
fn query_line(query: &str, theme: &Theme, height: f32) -> Rectangle {
    let caret = Rectangle::new()
        .width(size::LG * list::CARET_WIDTH)
        .height(size::LG * list::CARET_HEIGHT)
        .fill(theme.primary);

    let large = |text: String, color: Color| {
        Text::new(text)
            .font(SANS)
            .weight(Weight::Light)
            .size(size::LG)
            .color(color)
    };

    let items: Vec<Box<dyn Widget>> = if query.is_empty() {
        vec![
            Box::new(caret),
            Box::new(large(String::from("apps"), theme.outline_variant)),
        ]
    } else {
        vec![
            Box::new(large(tail(query, list::QUERY_CHARS), theme.on_surface)),
            Box::new(caret),
        ]
    };

    Rectangle::new()
        .width(Parent)
        .height(height)
        .align_child(Start, End)
        .child(Row::new(items).align(Center))
}

// the part of a long query that still fits, marked with an ellipsis
fn tail(text: &str, limit: usize) -> String {
    let count = text.chars().count();

    if count <= limit {
        return text.to_string();
    }

    let kept: String = text.chars().skip(count - limit.saturating_sub(1)).collect();

    format!("…{kept}")
}

// the groups' labels and rows, in a block that is always the same height
fn results(query: &str, selected: usize, theme: &Theme, monitor: &str, height: f32) -> Rectangle {
    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    let mut index = 0;

    for (position, group) in groups(query).iter().enumerate() {
        if position > 0 {
            items.push(Box::new(spacer(space::MD)));
        }

        items.push(Box::new(label(group, theme)));

        for entry in &group.entries {
            items.push(Box::new(row(entry, index, index == selected, theme, monitor)));

            index += 1;
        }
    }

    Rectangle::new()
        .width(Parent)
        .height(height)
        .clip()
        .child(Column::new(items).width(Parent))
}

fn label(group: &Group, theme: &Theme) -> Text {
    Text::new(group.label.to_uppercase())
        .font(MONO)
        .size(size::SM)
        .color(theme.on_surface_variant)
}

// the chosen row and the one under the pointer both turn primary, as every hover does
fn row(entry: &Entry, index: usize, selected: bool, theme: &Theme, monitor: &str) -> Rectangle {
    let key = hover::key(monitor, &format!("launcher/{index}"));

    let (name_color, note_color) = if selected || hover::is(&key) {
        (theme.primary, theme.primary)
    } else {
        (theme.on_surface, theme.on_surface_variant)
    };

    let name = Text::new(entry.name.clone())
        .font(SANS)
        .size(size::MD)
        .color(name_color)
        .elide();

    let note = Text::new(shorten(&entry.description, list::DESCRIPTION_CHARS))
        .font(MONO)
        .size(size::SM)
        .color(note_color);

    let target = entry.name.clone();

    Rectangle::new()
        .width(Parent)
        .height(size::MD * 1.5)
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(move |_| launch(&target))
        .align_child(Start, Center)
        .child(
            Row::new(children![name, note])
                .width(Parent)
                .gap(space::MD)
                .align(Center),
        )
}

// what the keys do, in the dim text tone
fn meta(theme: &Theme, height: f32) -> Rectangle {
    let hint = |text: &str| Text::new(text).font(MONO).size(size::SM).color(theme.outline);

    Rectangle::new()
        .width(Parent)
        .height(height)
        .align_child(Start, Center)
        .child(Row::new(children![hint("↵ open"), hint("esc close")]).gap(space::LG))
}
