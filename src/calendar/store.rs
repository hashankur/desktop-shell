use std::fs;
use std::path::PathBuf;
use std::time::SystemTime;

use super::Event;
use crate::files;
use crate::theme;

fn events_path() -> PathBuf {
    theme::state_folder().join("events")
}

/*
 * the last events google gave, kept so a restart, or a reload while
 * working on the shell, starts with them instead of empty or a fetch.
 * one event per line: start, end, all-day, uid and title, tab separated
 */
pub fn load_events() -> Vec<Event> {
    let text = fs::read_to_string(events_path()).unwrap_or_default();

    text.lines().filter_map(parse_event).collect()
}

pub fn save_events(events: &[Event]) {
    let text: String = events
        .iter()
        .map(|event| {
            format!(
                "{}\t{}\t{}\t{}\t{}\n",
                event.start,
                event.end,
                u8::from(event.all_day),
                clean(&event.uid),
                clean(&event.title)
            )
        })
        .collect();

    let _ = files::write_atomic(&events_path(), &text);
}

// when the events were last fetched, which is when they were last saved
pub fn fetched_at() -> Option<SystemTime> {
    fs::metadata(events_path()).ok()?.modified().ok()
}

pub fn forget_events() {
    let _ = fs::remove_file(events_path());
}

fn parse_event(line: &str) -> Option<Event> {
    let mut fields = line.splitn(5, '\t');

    Some(Event {
        start: fields.next()?.parse().ok()?,
        end: fields.next()?.parse().ok()?,
        all_day: fields.next()? == "1",
        uid: fields.next()?.to_string(),
        title: fields.next()?.to_string(),
    })
}

// a tab or a line break would split the line
fn clean(text: &str) -> String {
    text.replace(['\t', '\n', '\r'], " ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_an_event_line() {
        let event = parse_event("100\t200\t1\tuid@google.com\tLunch\twith a tab").unwrap();

        assert_eq!((event.start, event.end, event.all_day), (100, 200, true));
        assert_eq!(event.title, "Lunch\twith a tab");
        assert!(parse_event("100\t200").is_none());
        assert!(parse_event("soon\t200\t0\tuid\ttitle").is_none());
    }
}
