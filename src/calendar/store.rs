use std::fs;
use std::path::PathBuf;
use std::time::SystemTime;

use super::Event;
use crate::files;
use crate::theme;

/*
 * what signing in to google leaves behind: the desktop client it was done
 * with, the refresh token, and the short-lived access token with when it
 * runs out. one key=value per line, readable only by the user. it lives in
 * state, never in the config folder, which is a git repository
 */
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Credentials {
    pub client_id: String,
    pub client_secret: String,
    pub refresh_token: String,
    pub access_token: String,
    // seconds since 1970 when the access token stops working
    pub expires: i64,
}

impl Credentials {
    pub fn signed_in(&self) -> bool {
        !self.client_id.is_empty() && !self.refresh_token.is_empty()
    }

    pub fn load() -> Option<Self> {
        Some(Self::parse(&fs::read_to_string(credentials_path()).ok()?))
    }

    pub fn save(&self) -> bool {
        files::write_private(&credentials_path(), &self.to_text()).is_ok()
    }

    pub fn forget() {
        let _ = fs::remove_file(credentials_path());
    }

    fn parse(text: &str) -> Self {
        let mut credentials = Self::default();

        for line in text.lines() {
            let Some((key, value)) = line.split_once('=') else {
                continue;
            };

            let value = value.trim().to_string();

            match key.trim() {
                "client_id" => credentials.client_id = value,
                "client_secret" => credentials.client_secret = value,
                "refresh_token" => credentials.refresh_token = value,
                "access_token" => credentials.access_token = value,
                "expires" => credentials.expires = value.parse().unwrap_or(0),
                _ => {}
            }
        }

        credentials
    }

    fn to_text(&self) -> String {
        format!(
            "client_id={}\nclient_secret={}\nrefresh_token={}\naccess_token={}\nexpires={}\n",
            self.client_id, self.client_secret, self.refresh_token, self.access_token, self.expires
        )
    }
}

fn credentials_path() -> PathBuf {
    theme::state_folder().join("google")
}

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
    fn reads_back_what_it_writes() {
        let credentials = Credentials {
            client_id: String::from("id.apps.googleusercontent.com"),
            client_secret: String::from("secret"),
            refresh_token: String::from("1//refresh"),
            access_token: String::from("ya29.access"),
            expires: 1_794_355_200,
        };

        assert_eq!(Credentials::parse(&credentials.to_text()), credentials);
        assert!(credentials.signed_in());
        assert!(!Credentials::default().signed_in());
    }

    #[test]
    fn reads_an_event_line() {
        let event = parse_event("100\t200\t1\tuid@google.com\tLunch\twith a tab").unwrap();

        assert_eq!((event.start, event.end, event.all_day), (100, 200, true));
        assert_eq!(event.title, "Lunch\twith a tab");
        assert!(parse_event("100\t200").is_none());
        assert!(parse_event("soon\t200\t0\tuid\ttitle").is_none());
    }
}
