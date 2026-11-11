use amane::{
    Button, Center, Notifications, Parent, Pointer, Rectangle, Row, Service, Widget, children,
};

use super::{block, clickable, label, line, small};
use crate::hover;
use crate::surface::Surface;
use crate::text::shorten;
use crate::theme::{Theme, dash, size};
use crate::toast::{age, sender};

// one listed notification, copied out so the service isn't held while drawing
struct Note {
    id: u32,
    sender: String,
    summary: String,
    age: String,
}

/*
 * how many are waiting and the newest few: who sent it, what it says, how
 * long ago. a click runs its default action and closes the dashboard, a
 * right click dismisses it, and clear dismisses them all. none while
 * another daemon holds the notifications, so it never shows a false zero
 */
pub fn view(theme: &Theme, monitor: &str) -> Option<amane::Column> {
    let notifications = Notifications::read();

    if !notifications.running() {
        return None;
    }

    let count = notifications.list().len();

    let notes: Vec<Note> = notifications
        .list()
        .iter()
        .rev()
        .take(dash::NOTES)
        .map(|note| Note {
            id: note.id(),
            sender: sender(note),
            summary: summary(note.summary(), note.body()),
            age: age(note.received()),
        })
        .collect();

    drop(notifications);

    let noun = if count == 1 {
        "notification"
    } else {
        "notifications"
    };

    let mut head: Vec<Box<dyn Widget>> = vec![
        Box::new(label(&format!("{count} {noun}"), theme)),
        Box::new(Rectangle::new().width(Parent).height(size::SM * 1.5)),
    ];

    if count > 0 {
        head.push(Box::new(clear(theme, monitor)));
    }

    let lines = notes
        .into_iter()
        .map(|note| {
            let key = hover::key(monitor, &format!("dash/note/{}", note.id));
            let hovered = hover::amount(&key);
            let id = note.id;

            let row = line(
                &shorten(&note.sender, dash::LEAD_CHARS),
                &note.summary,
                &note.age,
                theme,
                hovered,
            );

            Box::new(clickable(row, key, move |button| match button {
                Button::Left => {
                    Notifications::click(id);
                    Surface::close();
                }

                Button::Right | Button::Middle => Notifications::dismiss(id),
            })) as Box<dyn Widget>
        })
        .collect();

    let head = Row::new(head).width(Parent).align(Center);

    Some(block(Box::new(head), lines))
}

// some senders put everything in the body and leave the summary empty
fn summary(summary: &str, body: &str) -> String {
    let summary = summary.trim();

    if !summary.is_empty() {
        return summary.to_string();
    }

    body.lines().next().unwrap_or_default().trim().to_string()
}

// dismisses every notification, the one way to clear them all
fn clear(theme: &Theme, monitor: &str) -> Rectangle {
    let key = hover::key(monitor, "dash/clear");

    let color = hover::mix(&key, theme.on_surface_variant, theme.primary);

    let text = small("clear", color);

    Rectangle::new()
        .width(Widget::width(&text))
        .height(size::SM * 1.5)
        .align_child(Center, Center)
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(|_| Notifications::clear())
        .child(Row::new(children![text]))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_empty_summary_falls_back_to_the_body() {
        assert_eq!(summary("Standup", "in 5 minutes"), "Standup");
        assert_eq!(summary("  ", "first line\nsecond"), "first line");
        assert_eq!(summary("", ""), "");
    }
}
