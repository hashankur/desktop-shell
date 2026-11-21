use std::path::PathBuf;
use std::time::SystemTime;

use amane::{
    Center, Color, Column, Notification, Notifications, Parent, Rectangle, Row, Service, Size,
    Widget,
};

use super::handle::Handle;
use super::icon::icon;
use super::{expand, note};
use super::parts::{label, line, small, spacer, text_button};
use crate::history::{self, Saved};
use crate::hover;
use crate::text::plain;
use crate::theme::{Theme, dash, space};
use crate::toast::{age, sender};

// one notification, live or kept, copied out so the service isn't held while drawing
pub struct Note {
    pub handle: Handle,
    pub summary: String,
    pub body: String,
    pub age: String,
    pub icon: Option<PathBuf>,
    // each button's key and its label; a kept notification has none
    pub actions: Vec<(String, String)>,
}

/*
 * how many are waiting, then each sender's newest, newest sender first, so
 * a chatty app takes one place instead of the whole column. senders are
 * listed while there is `room` for them, then counted. clear all dismisses
 * every one, the ones kept from an earlier run too. none while another
 * daemon holds the notifications, so it never shows a false zero
 */
pub fn view(theme: &Theme, monitor: &str, width: f32, room: f32) -> Option<Column> {
    let notifications = Notifications::read();

    if !notifications.running() {
        return None;
    }

    let tint = theme.on_surface_variant;

    // the live ones, then the ones kept from before, which are older
    let mut items: Vec<(String, Note)> = notifications
        .list()
        .iter()
        .rev()
        .map(|note| (sender(note.app_name()), copy(note, tint)))
        .collect();

    drop(notifications);

    items.extend(
        history::restored()
            .iter()
            .map(|saved| (sender(&saved.app), kept(saved, tint))),
    );

    let count = items.len();

    let noun = if count == 1 { "notification" } else { "notifications" };

    let mut head: Vec<Box<dyn Widget>> = vec![
        Box::new(label(&format!("{count} {noun}"), theme)),
        Box::new(Rectangle::new().width(Parent).height(line(dash::SMALL))),
    ];

    if count > 0 {
        let key = hover::key(monitor, "dash/clear");

        head.push(Box::new(text_button("clear all", key, theme, |_| history::clear_all())));
    }

    let mut column: Vec<Box<dyn Widget>> = vec![
        Box::new(Row::new(head).width(width).align(Center)),
        Box::new(spacer(space::MD)),
    ];

    if count == 0 {
        column.push(Box::new(small("nothing new", theme.outline)));
    }

    let mut used = line(dash::SMALL) + space::MD;
    let mut hidden = 0;

    for (who, notes) in group(items) {
        for (shown, stands_for) in note::entries(&who, &notes, expand::is_open(&who), theme, monitor, width) {
            let height = match Widget::height(&shown) {
                Size::Fixed(height) => height,
                Size::Parent => 0.0,
            };

            // once one doesn't fit, nothing after it is shown, so the order stays newest first
            if hidden == 0 && used + space::LG + height <= room {
                used += space::LG + height;

                column.push(Box::new(spacer(space::LG)));
                column.push(Box::new(shown));
            } else {
                hidden += stands_for;
            }
        }
    }

    if hidden > 0 {
        column.push(Box::new(spacer(space::LG)));
        column.push(Box::new(small(format!("{hidden} more"), theme.outline)));
    }

    Some(Column::new(column).width(width))
}

fn copy(note: &Notification, tint: Color) -> Note {
    let actions = note
        .actions()
        .iter()
        .map(|action| (action.key().to_string(), action.label().to_string()))
        .collect();

    let icon = icon(note.image(), note.icon(), note.app_name(), tint);

    make(Handle::Live(note.id()), (note.summary(), note.body()), note.received(), icon, actions)
}

// one from an earlier run: its buttons went with its sender
fn kept(saved: &Saved, tint: Color) -> Note {
    let icon = icon(&saved.image, &saved.icon, &saved.app, tint);

    make(Handle::Saved(saved.key), (&saved.summary, &saved.body), saved.received, icon, Vec::new())
}

fn make(
    handle: Handle,
    (title, text): (&str, &str),
    received: SystemTime,
    icon: Option<PathBuf>,
    actions: Vec<(String, String)>,
) -> Note {
    Note {
        handle,
        summary: summary(title, text),
        body: if title.trim().is_empty() { String::new() } else { plain(text) },
        age: age(received),
        icon,
        actions,
    }
}

// some senders put everything in the body and leave the summary empty
fn summary(summary: &str, body: &str) -> String {
    let summary = summary.trim();

    if !summary.is_empty() {
        return summary.to_string();
    }

    plain(body).lines().next().unwrap_or_default().trim().to_string()
}

// keeps the order keys first appear in, so the newest sender comes first
fn group<T>(items: Vec<(String, T)>) -> Vec<(String, Vec<T>)> {
    let mut groups: Vec<(String, Vec<T>)> = Vec::new();

    for (key, item) in items {
        match groups.iter_mut().find(|(seen, _)| *seen == key) {
            Some((_, list)) => list.push(item),
            None => groups.push((key, vec![item])),
        }
    }

    groups
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_empty_summary_falls_back_to_the_body() {
        assert_eq!(summary("Standup", "in 5 minutes"), "Standup");
        assert_eq!(summary("  ", "first line\nsecond"), "first line");
        assert_eq!(summary("", "<b>bold</b> start"), "bold start");
        assert_eq!(summary("", ""), "");
    }

    #[test]
    fn groups_by_sender_newest_first() {
        let items = vec![
            (String::from("discord"), 5),
            (String::from("signal"), 4),
            (String::from("discord"), 3),
            (String::from("firefox"), 2),
            (String::from("discord"), 1),
        ];

        assert_eq!(
            group(items),
            [
                (String::from("discord"), vec![5, 3, 1]),
                (String::from("signal"), vec![4]),
                (String::from("firefox"), vec![2]),
            ]
        );
    }
}
