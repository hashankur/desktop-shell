use std::io::Write;
use std::process::{Command, Stdio};
use std::thread;

use super::Event;
use super::encode::{form, percent};
use super::store::Credentials;
use super::time;

const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const API: &str = "https://www.googleapis.com/calendar/v3";

// an access token this close to running out is renewed first
const EXPIRY_MARGIN: i64 = 120;

// the calendars the user shows in google calendar, by id
const CALENDARS: &str = r#".items[]? | select((.selected // false) or (.primary // false)) | .id"#;

/*
 * one line per event: start, end, uid, title. cancelled ones and ones the
 * user declined are left out. @tsv escapes tabs and breaks in a title
 */
const EVENTS: &str = r#".items[]?
    | select(.status != "cancelled")
    | select([.attendees[]? | select(.self == true) | .responseStatus] | index("declined") | not)
    | [(.start.dateTime // .start.date // ""), (.end.dateTime // .end.date // ""),
       (.iCalUID // .id // ""), (.summary // "(untitled)")]
    | @tsv"#;

/*
 * every event between two instants on the calendars the user has shown,
 * sorted by start. a calendar that fails fails the whole fetch, so the
 * caller keeps what it had instead of showing half of it. a failure says
 * which step it was; a token that can't be renewed means signing in again
 */
pub fn events(credentials: &mut Credentials, from: i64, to: i64, now: i64, offset: i64) -> Result<Vec<Event>, &'static str> {
    let token = access_token(credentials, now)
        .ok_or("couldn't renew the access token; if it keeps failing, sign in again")?;

    let list = get(&format!("{API}/users/me/calendarList?minAccessRole=reader"), &token)
        .and_then(|list| jq(CALENDARS, &list))
        .ok_or("couldn't fetch the list of calendars")?;

    let window = form(&[
        ("singleEvents", "true"),
        ("orderBy", "startTime"),
        ("maxResults", "250"),
        ("timeMin", &time::rfc3339(from)),
        ("timeMax", &time::rfc3339(to)),
    ]);

    let mut events: Vec<Event> = Vec::new();

    for id in list.lines().filter(|id| !id.is_empty()) {
        let lines = get(&format!("{API}/calendars/{}/events?{window}", percent(id)), &token)
            .and_then(|body| jq(EVENTS, &body))
            .ok_or("couldn't fetch a calendar's events")?;

        for line in lines.lines() {
            let Some(event) = parse_line(line, offset) else {
                continue;
            };

            // an invite shows up on every calendar it was sent to
            if !events.iter().any(|seen| seen.uid == event.uid && seen.start == event.start) {
                events.push(event);
            }
        }
    }

    events.sort_by(|a, b| a.start.cmp(&b.start).then_with(|| a.title.cmp(&b.title)));

    Ok(events)
}

fn parse_line(line: &str, offset: i64) -> Option<Event> {
    let mut fields = line.split('\t');

    let (start, all_day) = time::parse(fields.next()?, offset)?;
    let (end, _) = time::parse(fields.next()?, offset)?;

    Some(Event {
        start,
        end: end.max(start),
        all_day,
        uid: unescape(fields.next()?),
        title: unescape(fields.next()?),
    })
}

// undoes @tsv's escapes; a title is one line, so breaks become spaces
fn unescape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars();

    while let Some(c) = chars.next() {
        if c != '\\' {
            out.push(c);
            continue;
        }

        match chars.next() {
            Some('t' | 'n' | 'r') => out.push(' '),
            Some(other) => out.push(other),
            None => out.push('\\'),
        }
    }

    out
}

/*
 * a working access token, renewed with the refresh token when it's about
 * to run out. a renewal is written back at once, so a restart reuses it
 */
fn access_token(credentials: &mut Credentials, now: i64) -> Option<String> {
    if !credentials.access_token.is_empty() && credentials.expires - EXPIRY_MARGIN > now {
        return Some(credentials.access_token.clone());
    }

    let body = form(&[
        ("client_id", &credentials.client_id),
        ("client_secret", &credentials.client_secret),
        ("refresh_token", &credentials.refresh_token),
        ("grant_type", "refresh_token"),
    ]);

    let (token, lasts) = token_reply(&post_token(&body)?)?;

    credentials.access_token = token.clone();
    credentials.expires = now + lasts;

    // signing out while this was out must not bring the file back
    if Credentials::load().is_some() {
        credentials.save();
    }

    Some(token)
}

// the token endpoint, with the secrets in the body on stdin, not in curl's arguments
pub fn post_token(body: &str) -> Option<String> {
    run("curl", &curl_args(&["--data", "@-", TOKEN_URL]), body)
}

// an access token and its lifetime in seconds, from the token endpoint's reply
pub fn token_reply(reply: &str) -> Option<(String, i64)> {
    let fields = jq(r#".access_token // "", .expires_in // 0"#, reply)?;
    let mut lines = fields.lines();

    let token = lines.next()?.to_string();
    let lasts = lines.next()?.parse().ok()?;

    (!token.is_empty()).then_some((token, lasts))
}

// a get with the token as a header read from stdin, so it never shows in ps
fn get(url: &str, token: &str) -> Option<String> {
    run(
        "curl",
        &curl_args(&["--header", "@-", url]),
        &format!("Authorization: Bearer {token}\n"),
    )
}

fn curl_args<'a>(rest: &[&'a str]) -> Vec<&'a str> {
    let mut args = vec!["--fail", "--silent", "--show-error", "--connect-timeout", "5", "--max-time", "20"];

    args.extend_from_slice(rest);

    args
}

// jq -r with the text on stdin
pub fn jq(filter: &str, input: &str) -> Option<String> {
    run("jq", &["-r", filter], input)
}

// a program with text on stdin; its output when it succeeds, none otherwise
pub fn run(program: &str, args: &[&str], input: &str) -> Option<String> {
    let mut child = Command::new(program)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;

    /*
     * written from its own thread: a long reply could fill the output pipe
     * while the input is still going in, and both sides would wait. the
     * pipe closes when the thread ends, so the program sees the end
     */
    let mut stdin = child.stdin.take()?;
    let input = input.to_string();
    let writer = thread::spawn(move || stdin.write_all(input.as_bytes()).is_ok());

    let output = child.wait_with_output().ok()?;

    if !writer.join().unwrap_or(false) {
        return None;
    }

    if !output.status.success() {
        return None;
    }

    Some(String::from_utf8_lossy(&output.stdout).into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    const LIST: &str = r##"{"items": [
        {"id": "me@gmail.com", "primary": true, "selected": true, "backgroundColor": "#9fe1e7"},
        {"id": "en.lk#holiday@group.v.calendar.google.com", "selected": true},
        {"id": "hidden@group.calendar.google.com"}
    ]}"##;

    const EVENT_LIST: &str = r#"{"items": [
        {"status": "confirmed", "summary": "Standup", "iCalUID": "a@google.com",
         "start": {"dateTime": "2026-11-11T10:15:00+05:30"}, "end": {"dateTime": "2026-11-11T10:30:00+05:30"}},
        {"status": "confirmed", "summary": "Poya\tDay", "iCalUID": "b@google.com",
         "start": {"date": "2026-11-11"}, "end": {"date": "2026-11-12"}},
        {"status": "cancelled", "summary": "Gone", "iCalUID": "c@google.com",
         "start": {"dateTime": "2026-11-11T12:00:00Z"}, "end": {"dateTime": "2026-11-11T13:00:00Z"}},
        {"status": "confirmed", "summary": "Declined", "iCalUID": "d@google.com",
         "attendees": [{"email": "x@y.z"}, {"self": true, "responseStatus": "declined"}],
         "start": {"dateTime": "2026-11-11T12:00:00Z"}, "end": {"dateTime": "2026-11-11T13:00:00Z"}},
        {"status": "confirmed", "iCalUID": "e@google.com",
         "attendees": [{"self": true, "responseStatus": "accepted"}],
         "start": {"dateTime": "2026-11-11T14:00:00Z"}, "end": {"dateTime": "2026-11-11T15:00:00Z"}}
    ]}"#;

    #[test]
    fn picks_the_shown_calendars() {
        let ids = jq(CALENDARS, LIST).unwrap();

        assert_eq!(ids.lines().collect::<Vec<_>>(), ["me@gmail.com", "en.lk#holiday@group.v.calendar.google.com"]);
    }

    #[test]
    fn flattens_events_and_drops_cancelled_and_declined() {
        let offset = 19_800;
        let lines = jq(EVENTS, EVENT_LIST).unwrap();

        let events: Vec<Event> = lines.lines().filter_map(|line| parse_line(line, offset)).collect();
        let titles: Vec<&str> = events.iter().map(|e| e.title.as_str()).collect();

        assert_eq!(titles, ["Standup", "Poya Day", "(untitled)"]);
        assert_eq!(events[0].end - events[0].start, 15 * 60);
        assert!(events[1].all_day);
        assert_eq!(events[1].end - events[1].start, time::DAY);
    }

    #[test]
    fn reads_a_token_reply() {
        let reply = r#"{"access_token": "ya29.x", "expires_in": 3599, "token_type": "Bearer"}"#;

        assert_eq!(token_reply(reply), Some((String::from("ya29.x"), 3599)));
        assert_eq!(token_reply(r#"{"error": "invalid_grant"}"#), None);
    }

    #[test]
    fn undoes_tsv_escapes() {
        assert_eq!(unescape(r"a\tb\\c"), r"a b\c");
    }
}
