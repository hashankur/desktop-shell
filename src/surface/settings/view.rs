use amane::{
    Center, Column, End, Monitor, Padding, Parent, Pointer, Rectangle, Row, Service, Start, Text,
    Weight, Widget, children,
};

use super::rows::{self, Action};
use super::{Page, Settings, choose, open_page, preview, scroll};
use crate::hover;
use crate::text::shorten;
use crate::theme::{MONO, SANS, Theme, grid, settings, size, space};

fn row_height() -> f32 {
    size::MD * 1.5
}

/*
 * bottom left, on the grid's first four columns, where the launcher sits: the
 * page's name as the one large element, the pages as small tabs under it,
 * then the page's rows, a name and its state, and what the keys do. the
 * rows keep one height whatever the page holds, so the hints never move
 */
pub fn view(theme: &Theme, monitor: &Monitor) -> Rectangle {
    let width = grid::span(settings::COLUMNS, monitor.width as f32);

    let settings_state = Settings::read();
    let (page, selected) = (settings_state.page, settings_state.selected);
    drop(settings_state);

    let rows = rows::rows(page);
    let selected = selected.min(rows.len().saturating_sub(1));

    let list_height = row_height() * settings::ROWS as f32;
    let meta_height = size::SM * 1.5;

    // the name and the tabs, measured so the wallpaper preview starts level with the rows
    let head = Column::new(children![
        Text::new(page.name())
            .font(SANS)
            .weight(Weight::Light)
            .size(size::LG)
            .color(theme.on_surface),
        spacer(space::MD),
        tabs(page, theme, &monitor.name),
        spacer(space::LG),
    ])
    .width(width);

    let head_height = fixed(Widget::height(&head));

    let thumb = match rows.get(selected).map(|row| &row.action) {
        Some(Action::Wallpaper(path)) => Settings::read()
            .pictures
            .get(path)
            .and_then(|picture| picture.thumb.clone()),
        _ => None,
    };

    let column = Column::new(children![
        head,
        list(&rows, selected, theme, &monitor.name, list_height),
        spacer(space::MD),
        meta(hints(&rows, selected), theme, meta_height),
    ])
    .width(width);

    let height = fixed(Widget::height(&column));

    /*
     * a click anywhere on the surface closes it through the scrim below, so
     * the block takes its own clicks and does nothing with them
     */
    let block = Rectangle::new()
        .width(width)
        .height(height)
        .on_click(|_| {})
        .child(column);

    let content = if page == Page::Appearance {
        preview::beside(block, thumb, head_height, list_height, monitor.width as f32)
    } else {
        Row::new(children![block])
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

fn fixed(size: amane::Size) -> f32 {
    match size {
        amane::Size::Fixed(size) => size,
        amane::Size::Parent => 0.0,
    }
}

fn spacer(height: f32) -> Rectangle {
    Rectangle::new().width(Parent).height(height)
}

fn small(text: impl Into<String>, color: amane::Color) -> Text {
    Text::new(text).font(MONO).size(size::SM).color(color)
}

// the pages in the small capitals every label uses; the open one in the text tone, the rest dimmed to the hints' tone, a hovered one primary
fn tabs(open: Page, theme: &Theme, monitor: &str) -> Row {
    let items: Vec<Box<dyn Widget>> = Page::ALL
        .into_iter()
        .map(|page| {
            let key = hover::key(monitor, &format!("settings/tab/{}", page.name()));

            let rest = if page == open {
                theme.on_surface
            } else {
                theme.outline
            };

            let color = hover::mix(&key, rest, theme.primary);

            let label = small(page.name().to_uppercase(), color);

            let width = match Widget::width(&label) {
                amane::Size::Fixed(width) => width,
                amane::Size::Parent => 0.0,
            };

            Box::new(
                Rectangle::new()
                    .width(width)
                    .height(size::SM * 1.5)
                    .cursor(Pointer)
                    .on_hover(move |inside| hover::set(&key, inside))
                    .on_click(move |_| open_page(page))
                    .align_child(Start, Center)
                    .child(label),
            ) as Box<dyn Widget>
        })
        .collect();

    Row::new(items).gap(space::LG).align(Center)
}

// the rows that fit, scrolled so the selected one is always among them
fn list(rows: &[rows::Row], selected: usize, theme: &Theme, monitor: &str, height: f32) -> Rectangle {
    let first = (selected + 1).saturating_sub(settings::ROWS);

    let items: Vec<Box<dyn Widget>> = rows
        .iter()
        .enumerate()
        .skip(first)
        .take(settings::ROWS)
        .map(|(index, row)| Box::new(line(row, index, index == selected, theme, monitor)) as Box<dyn Widget>)
        .collect();

    Rectangle::new()
        .width(Parent)
        .height(height)
        .clip()
        .child(Column::new(items).width(Parent))
}

// the selected row and the one under the pointer both turn primary, as every hover does
fn line(row: &rows::Row, index: usize, selected: bool, theme: &Theme, monitor: &str) -> Rectangle {
    let key = hover::key(monitor, &format!("settings/row/{index}"));

    let (name_rest, value_rest) = if row.action == Action::Nothing {
        (theme.on_surface_variant, theme.on_surface_variant)
    } else {
        (theme.on_surface, theme.on_surface_variant)
    };

    let name_color = hover::mix_selected(&key, selected, name_rest, theme.primary);
    let value_color = hover::mix_selected(&key, selected, value_rest, theme.primary);

    let name = Text::new(row.name.clone())
        .font(SANS)
        .size(size::MD)
        .color(name_color)
        .elide();

    let value = small(shorten(&row.value, settings::VALUE_CHARS), value_color);

    Rectangle::new()
        .width(Parent)
        .height(row_height())
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(move |_| choose(index))
        .on_scroll(move |delta| scroll(index, delta))
        .align_child(Start, Center)
        .child(Row::new(children![name, value]).width(Parent).gap(space::MD).align(Center))
}

// what the keys do here; the level keys only show on a row that has a level
fn hints(rows: &[rows::Row], selected: usize) -> Vec<&'static str> {
    let mut hints = vec!["←→ page", "↑↓ select"];

    match rows.get(selected).map(|row| &row.action) {
        Some(Action::Volume) => hints.extend(["↵ mute", "-+ level"]),
        Some(Action::Brightness) => hints.push("-+ level"),
        Some(Action::Nothing) | None => {}
        Some(_) => hints.push("↵ choose"),
    }

    hints.push("esc close");

    hints
}

// what the keys do, in the dim text tone
fn meta(hints: Vec<&'static str>, theme: &Theme, height: f32) -> Rectangle {
    let items: Vec<Box<dyn Widget>> = hints
        .into_iter()
        .map(|hint| Box::new(small(hint, theme.outline)) as Box<dyn Widget>)
        .collect();

    Rectangle::new()
        .width(Parent)
        .height(height)
        .align_child(Start, Center)
        .child(Row::new(items).gap(space::LG))
}
