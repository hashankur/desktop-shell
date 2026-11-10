use std::time::SystemTime;

use amane::{
    Center, Column, Notification, Notifications, Pointer, Rectangle, Row, Text, Urgency, Widget,
};

use crate::hover;
use crate::theme::{MONO, SANS, Theme, size, space, toast};

/*
 * a line or two of text and nothing around it: who sent it and when, small;
 * what it says, medium; the body, small, cut after two lines; then whatever
 * buttons it asked for, as small text. a critical one says so with its
 * first line in the accent
 */
pub fn view(note: &Notification, theme: &Theme, width: f32, monitor: &str) -> Column {
    let key = hover::key(monitor, "toast");
    let hovered = hover::is(&key);

    let accent = if note.urgency() == Urgency::Critical {
        theme.primary
    } else {
        theme.on_surface_variant
    };

    let head = Text::new(format!("{} · {}", sender(note), age(note.received())))
        .font(MONO)
        .size(size::SM)
        .color(accent);

    let summary = Text::new(note.summary().to_string())
        .font(SANS)
        .size(size::MD)
        .color(if hovered { theme.primary } else { theme.on_surface })
        .elide();

    let mut lines: Vec<Box<dyn Widget>> = vec![Box::new(head), Box::new(summary)];

    if !note.body().trim().is_empty() {
        lines.push(Box::new(
            Text::new(note.body().trim().to_string())
                .font(MONO)
                .size(size::SM)
                .color(theme.on_surface_variant)
                .wrap()
                .max_lines(toast::BODY_LINES),
        ));
    }

    if !note.actions().is_empty() {
        lines.push(Box::new(actions(note, theme, monitor)));
    }

    Column::new(lines).width(width).gap(space::SM / 2.0)
}

// the app's name, lowercased like every small label; some senders leave it empty
fn sender(note: &Notification) -> String {
    let name = note.app_name().trim();

    if name.is_empty() {
        String::from("notification")
    } else {
        name.to_lowercase()
    }
}

fn age(received: SystemTime) -> String {
    let seconds = SystemTime::now()
        .duration_since(received)
        .map(|age| age.as_secs())
        .unwrap_or(0);

    match seconds {
        0..60 => String::from("now"),
        60..3600 => format!("{}m", seconds / 60),
        _ => format!("{}h", seconds / 3600),
    }
}

// the buttons a notification asks for, as small text that turns primary under the pointer
fn actions(note: &Notification, theme: &Theme, monitor: &str) -> Row {
    let id = note.id();

    let items: Vec<Box<dyn Widget>> = note
        .actions()
        .iter()
        .enumerate()
        .map(|(index, action)| {
            let key = hover::key(monitor, &format!("toast-action/{index}"));

            let color = if hover::is(&key) {
                theme.primary
            } else {
                theme.on_surface_variant
            };

            let label = Text::new(action.label().to_lowercase())
                .font(MONO)
                .size(size::SM)
                .color(color);

            let width = Widget::width(&label);
            let target = action.key().to_string();

            Box::new(
                Rectangle::new()
                    .width(width)
                    .height(size::SM * 1.5)
                    .align_child(Center, Center)
                    .cursor(Pointer)
                    .on_hover(move |inside| hover::set(&key, inside))
                    .on_click(move |_| Notifications::invoke(id, &target))
                    .child(label),
            ) as Box<dyn Widget>
        })
        .collect();

    Row::new(items).gap(space::MD).align(Center)
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;

    #[test]
    fn ages_read_like_the_prototype() {
        let now = SystemTime::now();

        assert_eq!(age(now), "now");
        assert_eq!(age(now - Duration::from_secs(5 * 60 + 10)), "5m");
        assert_eq!(age(now - Duration::from_secs(2 * 3600)), "2h");

        // a clock that moved backwards still reads as new
        assert_eq!(age(now + Duration::from_secs(30)), "now");
    }
}
