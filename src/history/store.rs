use std::time::{Duration, SystemTime, UNIX_EPOCH};

use super::Saved;

/*
 * one line per notification, newest last: the time it came as seconds, then
 * the app, icon, image, summary and body, split by tabs. a backslash, tab
 * or line break inside a field is written as an escape, so a body of any
 * length stays on its one line
 */
pub fn encode(entries: &[Saved]) -> String {
    let mut text = String::new();

    for entry in entries {
        let seconds = entry
            .received
            .duration_since(UNIX_EPOCH)
            .map_or(0, |since| since.as_secs());

        let fields = [
            seconds.to_string(),
            escape(&entry.app),
            escape(&entry.icon),
            escape(&entry.image),
            escape(&entry.summary),
            escape(&entry.body),
        ];

        text.push_str(&fields.join("\t"));
        text.push('\n');
    }

    text
}

// a line that doesn't read is skipped, so one bad write never loses the rest
pub fn decode(text: &str) -> Vec<Saved> {
    text.lines().filter_map(line).collect()
}

fn line(text: &str) -> Option<Saved> {
    let fields: Vec<&str> = text.split('\t').collect();

    let [seconds, app, icon, image, summary, body] = fields.as_slice() else {
        return None;
    };

    let seconds: u64 = seconds.parse().ok()?;

    Some(Saved {
        key: 0,
        app: unescape(app),
        summary: unescape(summary),
        body: unescape(body),
        icon: unescape(icon),
        image: unescape(image),
        received: UNIX_EPOCH + Duration::from_secs(seconds),
        live: None,
    })
}

fn escape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());

    for letter in text.chars() {
        match letter {
            '\\' => out.push_str("\\\\"),
            '\t' => out.push_str("\\t"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            other => out.push(other),
        }
    }

    out
}

fn unescape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut letters = text.chars();

    while let Some(letter) = letters.next() {
        if letter != '\\' {
            out.push(letter);

            continue;
        }

        match letters.next() {
            Some('t') => out.push('\t'),
            Some('n') => out.push('\n'),
            Some('r') => out.push('\r'),
            Some(other) => out.push(other),
            None => out.push('\\'),
        }
    }

    out
}

pub fn expired(received: SystemTime, now: SystemTime) -> bool {
    let keep = Duration::from_secs(crate::theme::history::KEEP_DAYS * 24 * 3600);

    now.duration_since(received).is_ok_and(|age| age > keep)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn saved(body: &str, seconds: u64) -> Saved {
        Saved {
            key: 0,
            app: String::from("signal"),
            summary: String::from("Ana"),
            body: String::from(body),
            icon: String::new(),
            image: String::from("/run/user/1000/avatar.png"),
            received: UNIX_EPOCH + Duration::from_secs(seconds),
            live: None,
        }
    }

    #[test]
    fn a_body_with_tabs_breaks_and_slashes_comes_back_whole() {
        let entries = vec![saved("a\tb\nc\\n d\r\ne", 100), saved("", 200)];

        let text = encode(&entries);

        assert_eq!(text.lines().count(), 2);
        assert_eq!(decode(&text), entries);
    }

    #[test]
    fn a_line_that_does_not_read_is_skipped() {
        let text = format!("junk\nnot-a-number\ta\tb\tc\td\te\n{}", encode(&[saved("kept", 5)]));

        assert_eq!(decode(&text), [saved("kept", 5)]);
    }

    #[test]
    fn expires_after_the_days_kept() {
        let now = SystemTime::now();
        let day = Duration::from_secs(24 * 3600);

        assert!(!expired(now - day, now));
        assert!(expired(now - day * 4, now));

        // a clock that moved backwards keeps it
        assert!(!expired(now + day, now));
    }
}
