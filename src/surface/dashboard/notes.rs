use std::path::{Path, PathBuf};

use amane::{
    Apps, Center, Color, Column, Notification, Notifications, Parent, Rectangle, Row, Service,
    Size, Widget,
};

use super::{expand, note};
use super::parts::{label, line, small, spacer, text_button};
use crate::hover;
use crate::icons;
use crate::text::plain;
use crate::theme::{Theme, dash, space};
use crate::toast::{age, sender};

// one notification, copied out so the service isn't held while drawing
pub struct Note {
    pub id: u32,
    pub summary: String,
    pub body: String,
    pub age: String,
    pub icon: Option<PathBuf>,
    // each button's key and its label
    pub actions: Vec<(String, String)>,
}

/*
 * how many are waiting, then each sender's newest, newest sender first, so
 * a chatty app takes one place instead of the whole column. senders are
 * listed while there is `room` for them, then counted. clear all dismisses
 * every one. none while another daemon holds the notifications, so it
 * never shows a false zero
 */
pub fn view(theme: &Theme, monitor: &str, width: f32, room: f32) -> Option<Column> {
    let notifications = Notifications::read();

    if !notifications.running() {
        return None;
    }

    let count = notifications.list().len();

    let items: Vec<(String, Note)> = notifications
        .list()
        .iter()
        .rev()
        .map(|note| (sender(note), copy(note, theme.on_surface_variant)))
        .collect();

    drop(notifications);

    let noun = if count == 1 { "notification" } else { "notifications" };

    let mut head: Vec<Box<dyn Widget>> = vec![
        Box::new(label(&format!("{count} {noun}"), theme)),
        Box::new(Rectangle::new().width(Parent).height(line(dash::SMALL))),
    ];

    if count > 0 {
        let key = hover::key(monitor, "dash/clear");

        head.push(Box::new(text_button("clear all", key, theme, |_| Notifications::clear())));
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
    Note {
        id: note.id(),
        summary: summary(note.summary(), note.body()),
        body: if note.summary().trim().is_empty() {
            String::new()
        } else {
            plain(note.body())
        },
        age: age(note.received()),
        icon: icon(note, tint),
        actions: note
            .actions()
            .iter()
            .map(|action| (action.key().to_string(), action.label().to_string()))
            .collect(),
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

/*
 * the notification's own picture if it sent one, like an avatar, then its
 * icon if that's a file, then the icon of the app it names or comes from.
 * a system one names a theme icon instead, like "battery-low", which has
 * no app, so last comes the symbolic icon, tinted like the text beside it
 */
fn icon(note: &Notification, tint: Color) -> Option<PathBuf> {
    full_color(note).or_else(|| {
        let (name, app) = (note.icon().trim(), note.app_name().trim());

        (!name.is_empty())
            .then(|| icons::symbolic(name, tint))
            .flatten()
            .or_else(|| icons::app(app, tint))
    })
}

fn full_color(note: &Notification) -> Option<PathBuf> {
    let file = |text: &str| {
        let path = text.trim().strip_prefix("file://").unwrap_or(text.trim());

        path.starts_with('/').then(|| PathBuf::from(path))
    };

    if let Some(path) = file(note.image()).or_else(|| file(note.icon())) {
        return Some(path);
    }

    let (name, app) = (note.icon().trim(), note.app_name().trim());

    let matches = |text: &str, wanted: &str| !wanted.is_empty() && text.eq_ignore_ascii_case(wanted);

    Apps::read()
        .list()
        .iter()
        .find(|entry| {
            let icon = entry.icon().unwrap_or_default();

            matches(icon, name) || matches(icon, app) || matches(entry.name(), app)
        })
        .and_then(|entry| entry.icon_path())
        .map(Path::to_path_buf)
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
