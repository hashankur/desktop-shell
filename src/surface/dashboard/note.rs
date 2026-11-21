use amane::{
    Button, Center, Column, Image, Notifications, Parent, Pointer, Rectangle, Row, Size, Start,
    Text, Widget, children,
};

use super::body::body;
use super::expand;
use super::handle::Handle;
use super::notes::Note;
use super::parts::{line, small, spacer, text_button};
use crate::hover;
use crate::theme::{SANS, Theme, dash, space};

/*
 * a sender's notifications as the places they take in the column, each with
 * how many notifications it stands for. folded, that is one: the newest,
 * with how many more there are and a way to unfold. unfolded, every one in
 * turn, newest first, with the way to fold again under the first, where it
 * stays on screen however long the rest runs
 */
pub fn entries(
    sender: &str,
    notes: &[Note],
    open: bool,
    theme: &Theme,
    monitor: &str,
    width: f32,
) -> Vec<(Rectangle, usize)> {
    let count = notes.len();

    let toggle = |text: String| {
        let key = hover::key(monitor, &format!("dash/group/{sender}"));
        let name = sender.to_string();

        text_button(&text, key, theme, move |_| expand::toggle(&name))
    };

    let heading = if count > 1 {
        format!("{sender} · {count}")
    } else {
        sender.to_string()
    };

    if !open || count < 2 {
        let foot = (count > 1).then(|| toggle(format!("+{} more from {sender}", count - 1)));

        return notes
            .first()
            .map(|note| (view(note, &heading, foot, theme, monitor, width), count))
            .into_iter()
            .collect();
    }

    notes
        .iter()
        .enumerate()
        .map(|(index, note)| {
            let (who, foot) = if index == 0 {
                (heading.as_str(), Some(toggle(String::from("show less"))))
            } else {
                (sender, None)
            };

            (view(note, who, foot, theme, monitor, width), 1)
        })
        .collect()
}

/*
 * one notification: its icon, who and when, the summary, the body cut after
 * a couple of lines with a way to unfold it, the buttons it asked for, and a foot
 * if the group has one. a click runs its default action and closes the dashboard,
 * or dismisses a kept one; "clear" or a
 * right click dismisses it, and the sender's next one takes its place
 */
fn view(note: &Note, who: &str, foot: Option<Rectangle>, theme: &Theme, monitor: &str, width: f32) -> Rectangle {
    let handle = note.handle;
    let tag = handle.tag();
    let key = hover::key(monitor, &format!("dash/note/{tag}"));
    let text_width = (width - dash::ICON - space::MD).max(0.0);

    // its own click is the innermost, so it never also opens the notification
    let clear = {
        let key = hover::key(monitor, &format!("dash/note/{tag}/clear"));

        text_button("clear", key, theme, move |_| handle.dismiss())
    };

    let top = Row::new(children![
        small(who, theme.on_surface_variant),
        Rectangle::new().width(Parent).height(line(dash::SMALL)),
        small(note.age.as_str(), theme.on_surface_variant),
        clear
    ])
    .gap(space::MD)
    .width(text_width)
    .align(Center);

    let summary = Text::new(note.summary.as_str())
        .font(SANS)
        .size(dash::TEXT)
        .weight(dash::SUMMARY_WEIGHT)
        .color(hover::mix(&key, theme.on_surface, theme.primary))
        .elide();

    let mut lines: Vec<Box<dyn Widget>> = vec![Box::new(top), Box::new(summary)];

    if !note.body.is_empty() {
        let open = expand::is_note_open(handle);
        let (text, more) = body(&note.body, text_width, open, theme);

        lines.push(Box::new(text));

        // a body that fits in the folded lines has nothing to open
        if more {
            let key = hover::key(monitor, &format!("dash/note/{tag}/more"));
            let name = if open { "less" } else { "more" };

            lines.push(Box::new(text_button(name, key, theme, move |_| expand::toggle_note(handle))));
        }
    }

    if !note.actions.is_empty() {
        lines.push(Box::new(spacer(space::XS)));
        lines.push(Box::new(actions(note, theme, monitor)));
    }

    // the foot's own click is the innermost, so it never also opens the notification
    if let Some(foot) = foot {
        lines.push(Box::new(foot));
    }

    let icon = Rectangle::new().width(dash::ICON).height(dash::ICON);

    let icon = match &note.icon {
        Some(path) => icon.fill(Image::contain(path.clone())),
        None => icon,
    };

    let row = Row::new(children![icon, Column::new(lines).width(text_width)])
        .width(width)
        .gap(space::MD)
        .align(Start);

    let height = match Widget::height(&row) {
        Size::Fixed(height) => height,
        Size::Parent => 0.0,
    };

    Rectangle::new()
        .width(width)
        .height(height)
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(move |button| match button {
            Button::Left => handle.click(),
            Button::Right | Button::Middle => handle.dismiss(),
        })
        .child(row)
}

// the buttons a notification asks for, as small text that turns primary under the pointer
fn actions(note: &Note, theme: &Theme, monitor: &str) -> Row {
    // a kept notification has none, its sender is gone
    let Handle::Live(id) = note.handle else {
        return Row::new(Vec::new());
    };

    let tag = note.handle.tag();

    let items: Vec<Box<dyn Widget>> = note
        .actions
        .iter()
        .enumerate()
        .map(|(index, (target, name))| {
            let key = hover::key(monitor, &format!("dash/note/{tag}/action/{index}"));
            let target = target.clone();

            Box::new(text_button(&name.to_lowercase(), key, theme, move |_| {
                Notifications::invoke(id, &target)
            })) as Box<dyn Widget>
        })
        .collect();

    Row::new(items).gap(space::MD).align(Center)
}
