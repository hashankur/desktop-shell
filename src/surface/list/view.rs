use amane::{
    Center, Color, Column, End, Monitor, Padding, Parent, Pointer, Rectangle, Row, Service, Start,
    Text, Weight, Widget, children,
};

use super::{Entry, Group, ListState};
use crate::hover;
use crate::text::shorten;
use crate::theme::{MONO, SANS, Theme, grid, list, size, space};

// what a list surface shows: its ghost word, its rows, its key hints, and what picking a row does.
// `long_query` sets what is typed smaller, for a query that is a sentence rather than a name
pub struct Spec<'a> {
    pub placeholder: &'a str,
    pub groups: Vec<Group>,
    pub hints: &'a [&'a str],
    pub pick: fn(&str),
    pub long_query: bool,

    // something shown beside the list, level with its top, like the clipboard's preview
    pub beside: Option<Beside>,
}

// a block that starts after `column` grid columns and spans `columns`, as tall as the list or shorter
pub struct Beside {
    pub column: u32,
    pub columns: u32,
    pub content: Rectangle,
}

// the list's fixed height, which anything shown beside it keeps to
pub fn list_height() -> f32 {
    size::MD * 1.5 * list::ROWS + space::MD * 2.0
}

/*
 * bottom left, on the grid's first four columns, as the design table says.
 * the list has a fixed height, so the query above it stays where it is
 * however many results there are
 */
pub fn view(theme: &Theme, monitor: &Monitor, mut spec: Spec) -> Rectangle {
    let state = ListState::read();
    let (query, selected) = (state.query.clone(), state.selected);
    drop(state);

    let width = grid::span(4, monitor.width as f32);

    let query_height = size::LG * 1.1;
    let list_height = list_height();
    let meta_height = size::SM * 1.5;

    let total = query_height + space::LG + list_height + space::MD + meta_height;

    let column = Column::new(children![
        query_line(&query, spec.placeholder, spec.long_query, theme, query_height),
        spacer(space::LG),
        results(&spec, selected, theme, &monitor.name, list_height),
        spacer(space::MD),
        meta(spec.hints, theme, meta_height),
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

    let content = match spec.beside.take() {
        Some(beside) => next_to(block, beside, query_height + space::LG, width, monitor.width as f32),
        None => Row::new(children![block]),
    };

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
        .child(content)
}

// the list block, then the other block from its own grid column, starting `top` down
fn next_to(block: Rectangle, beside: Beside, top: f32, block_width: f32, screen_width: f32) -> Row {
    let start = grid::span(beside.column, screen_width) + grid::GUTTER;

    let gap = Rectangle::new().width(start - block_width).height(1.0);

    let width = grid::span(beside.columns, screen_width);

    let column = Column::new(children![spacer(top), beside.content]).width(width);

    Row::new(children![block, gap, column])
}

fn spacer(height: f32) -> Rectangle {
    Rectangle::new().width(Parent).height(height)
}

// the one large element: what is typed, with a caret, or the ghost word before anything is
fn query_line(query: &str, placeholder: &str, long: bool, theme: &Theme, height: f32) -> Rectangle {
    let (size, chars) = if long {
        (list::LONG_QUERY, list::LONG_QUERY_CHARS)
    } else {
        (size::LG, list::QUERY_CHARS)
    };

    let caret = Rectangle::new()
        .width(size * list::CARET_WIDTH)
        .height(size * list::CARET_HEIGHT)
        .fill(theme.primary);

    let large = |text: String, color: Color| {
        Text::new(text)
            .font(SANS)
            .weight(Weight::Light)
            .size(size)
            .color(color)
    };

    let items: Vec<Box<dyn Widget>> = if query.is_empty() {
        vec![
            Box::new(caret),
            Box::new(large(placeholder.to_string(), theme.outline_variant)),
        ]
    } else {
        vec![
            Box::new(large(tail(query, chars), theme.on_surface)),
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
fn results(spec: &Spec, selected: usize, theme: &Theme, monitor: &str, height: f32) -> Rectangle {
    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    let mut index = 0;

    for (position, group) in spec.groups.iter().enumerate() {
        if position > 0 {
            items.push(Box::new(spacer(space::MD)));
        }

        items.push(Box::new(label(group, theme)));

        for entry in &group.entries {
            let chosen = index == selected;

            items.push(Box::new(row(entry, index, chosen, spec.pick, theme, monitor)));

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
fn row(
    entry: &Entry,
    index: usize,
    selected: bool,
    pick: fn(&str),
    theme: &Theme,
    monitor: &str,
) -> Rectangle {
    let key = hover::key(monitor, &format!("list/{index}"));

    let name_color = hover::mix_selected(&key, selected, theme.on_surface, theme.primary);
    let note_color = hover::mix_selected(&key, selected, theme.on_surface_variant, theme.primary);

    let name = Text::new(entry.name.clone())
        .font(SANS)
        .size(size::MD)
        .color(name_color)
        .elide();

    let note = Text::new(shorten(&entry.description, list::DESCRIPTION_CHARS))
        .font(MONO)
        .size(size::SM)
        .color(note_color);

    let target = entry.id.clone();

    Rectangle::new()
        .width(Parent)
        .height(size::MD * 1.5)
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(move |_| pick(&target))
        .align_child(Start, Center)
        .child(
            Row::new(children![name, note])
                .width(Parent)
                .gap(space::MD)
                .align(Center),
        )
}

// what the keys do, in the dim text tone
fn meta(hints: &[&str], theme: &Theme, height: f32) -> Rectangle {
    let items: Vec<Box<dyn Widget>> = hints
        .iter()
        .map(|hint| {
            Box::new(Text::new(*hint).font(MONO).size(size::SM).color(theme.outline))
                as Box<dyn Widget>
        })
        .collect();

    Rectangle::new()
        .width(Parent)
        .height(height)
        .align_child(Start, Center)
        .child(Row::new(items).gap(space::LG))
}
