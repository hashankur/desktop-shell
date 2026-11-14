use amane::Service;

/*
 * the senders whose notifications are listed in full instead of just their
 * newest. only one surface is open at a time, so this starts over, all
 * folded, every time the dashboard opens
 */
#[derive(Default)]
pub struct Expanded {
    senders: Vec<String>,
}

impl Service for Expanded {
    fn new() -> Self {
        Self::default()
    }

    // only changes through clicks
    fn listen() {}
}

pub fn reset() {
    if !Expanded::read().senders.is_empty() {
        Expanded::write().senders.clear();
    }
}

pub fn is_open(sender: &str) -> bool {
    Expanded::read().senders.iter().any(|open| open == sender)
}

pub fn toggle(sender: &str) {
    flip(&mut Expanded::write().senders, sender);
}

fn flip(senders: &mut Vec<String>, sender: &str) {
    match senders.iter().position(|open| open == sender) {
        Some(index) => {
            senders.remove(index);
        }

        None => senders.push(sender.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_click_opens_a_sender_and_the_next_folds_it() {
        let mut senders = Vec::new();

        flip(&mut senders, "discord");
        flip(&mut senders, "signal");
        assert_eq!(senders, ["discord", "signal"]);

        flip(&mut senders, "discord");
        assert_eq!(senders, ["signal"]);
    }
}
