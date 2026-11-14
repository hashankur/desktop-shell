
use super::Event;
use crate::google::encode::{form, percent, unescape};
use crate::google::{access_token, get, jq};
use super::time;

const API: &str = "https://www.googleapis.com/calendar/v3";

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
pub fn events(from: i64, to: i64, now: i64, offset: i64) -> Result<Vec<Event>, &'static str> {
    let token = access_token(now)
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
}
