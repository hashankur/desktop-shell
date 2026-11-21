use amane::Service;

use super::handle::Handle;

/*
 * the senders whose notifications are listed in full instead of just their
 * newest, and the notifications whose whole body is shown instead of its
 * first lines. only one surface is open at a time, so this starts over, all
 * folded, every time the dashboard opens
 */
#[derive(Default)]
pub struct Expanded {
    senders: Vec<String>,
    notes: Vec<Handle>,
}

impl Service for Expanded {
    fn new() -> Self {
        Self::default()
    }

    // only changes through clicks
    fn listen() {}
}

pub fn reset() {
    let open = Expanded::read();
    let any = !open.senders.is_empty() || !open.notes.is_empty();

    drop(open);

    if any {
        let mut open = Expanded::write();

        open.senders.clear();
        open.notes.clear();
    }
}

pub fn is_open(sender: &str) -> bool {
    Expanded::read().senders.iter().any(|open| open == sender)
}

pub fn toggle(sender: &str) {
    flip(&mut Expanded::write().senders, sender.to_string());
}

// a live id stays with a notification its sender replaces, so an unfolded body stays unfolded
pub fn is_note_open(note: Handle) -> bool {
    Expanded::read().notes.contains(&note)
}

pub fn toggle_note(note: Handle) {
    flip(&mut Expanded::write().notes, note);
}

fn flip<T: PartialEq>(open: &mut Vec<T>, item: T) {
    match open.iter().position(|seen| *seen == item) {
        Some(index) => {
            open.remove(index);
        }

        None => open.push(item),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_click_opens_a_sender_and_the_next_folds_it() {
        let mut senders = Vec::new();

        flip(&mut senders, String::from("discord"));
        flip(&mut senders, String::from("signal"));
        assert_eq!(senders, ["discord", "signal"]);

        flip(&mut senders, String::from("discord"));
        assert_eq!(senders, ["signal"]);
    }

    #[test]
    fn a_notification_opens_and_folds_by_id() {
        let mut notes = Vec::new();

        flip(&mut notes, Handle::Live(4));
        flip(&mut notes, Handle::Saved(4));
        assert_eq!(notes, [Handle::Live(4), Handle::Saved(4)]);

        flip(&mut notes, Handle::Live(4));
        assert_eq!(notes, [Handle::Saved(4)]);
    }
}
