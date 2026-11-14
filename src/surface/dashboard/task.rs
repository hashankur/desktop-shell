use amane::{Center, Color, Image, Parent, Rectangle, Row, Start, Text, children};

use super::parts::{button, line, small};
use crate::hover;
use crate::icons;
use crate::tasks::{self, Task, due};
use crate::theme::{SANS, Theme, dash, space};

/*
 * a task in the agenda: its tick where an event's hours go, its title a
 * step quieter than an event's, and at the end how late it is, or which
 * list it's on when that isn't the main one. the tick ticks it off at
 * google, or back on until the next fetch drops it
 */
pub fn entry(task: &Task, list: &str, today: i64, theme: &Theme, monitor: &str) -> Row {
    let late = !task.done && task.due.is_some_and(|day| day < today);

    let key = hover::key(monitor, &format!("dash/task/{}", task.id));

    let rest = if late { theme.error } else { theme.outline };
    let ring = hover::mix(&key, rest, theme.primary);

    let id = task.id.clone();
    let tick = button(tick(task.done, ring, theme), key, move |_| tasks::toggle(&id));

    let time = Rectangle::new()
        .width(dash::TIME)
        .height(line(dash::AGENDA))
        .align_child(Start, Center)
        .child(tick);

    let title_color = if task.done { theme.outline } else { theme.on_surface_variant };

    let title = Text::new(task.title.clone())
        .font(SANS)
        .size(dash::AGENDA)
        .color(title_color)
        .elide();

    let (trailing, trailing_color) = match task.due {
        _ if task.done => (String::from("done"), theme.outline),
        Some(day) if late => (due::label(day, today), theme.error),
        _ => (list.to_string(), theme.outline),
    };

    Row::new(children![time, title, small(trailing, trailing_color)])
        .width(Parent)
        .gap(space::MD)
        .align(Center)
}

// an empty ring, or a filled one with a check once done
fn tick(done: bool, ring: Color, theme: &Theme) -> Rectangle {
    let mark = Rectangle::new()
        .width(dash::TICK)
        .height(dash::TICK)
        .radius(dash::TICK / 2.0)
        .align_child(Center, Center);

    if !done {
        return mark.border(dash::TICK_BORDER, ring);
    }

    let mark = mark.fill(theme.outline_variant);

    match icons::symbolic("object-select", theme.on_surface_variant) {
        Some(path) => mark.child(
            Rectangle::new()
                .width(dash::CHECK)
                .height(dash::CHECK)
                .fill(Image::contain(path)),
        ),
        None => mark,
    }
}
