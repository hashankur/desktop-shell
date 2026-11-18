use super::Event;
use super::days::on_day;
use super::time::{DAY, midnight};
use crate::clock::{civil_date, twelve_hour};

// how far ahead the bar looks for something coming up, in days after today
pub const AHEAD: i64 = 7;

// up to this many minutes away, the countdown counts minutes
const SOON: i64 = 30;

// past this many minutes the bar shows the time of day, not a countdown
const FAR: i64 = 3 * 60;

// 1970-01-01 was a thursday
pub(super) const WEEKDAYS: [&str; 7] = ["thu", "fri", "sat", "sun", "mon", "tue", "wed"];

const MONTHS: [&str; 12] = [
    "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
];

/*
 * what the bar's countdown is about, as neue picked it: a timed event going
 * on now, then the rest of today, then an all-day one going on now, then
 * the coming week. an all-day event is on from midnight, so putting it
 * first would let a holiday hide the meeting that's actually next
 */
pub fn next(events: &[Event], now: i64, offset: i64) -> Option<&Event> {
    let today = midnight(now, offset);
    let tomorrow = today + DAY;
    let horizon = tomorrow + AHEAD * DAY;

    let earliest = |found: Option<&Event>, event: &Event| -> bool {
        found.is_none_or(|found| event.start < found.start)
    };

    let mut ongoing_timed: Option<&Event> = None;
    let mut ongoing_all_day: Option<&Event> = None;
    let mut later_today: Option<&Event> = None;
    let mut this_week: Option<&Event> = None;

    for event in events {
        if event.start <= now && event.end > now {
            let slot = if event.all_day { &mut ongoing_all_day } else { &mut ongoing_timed };

            if earliest(*slot, event) {
                *slot = Some(event);
            }
        } else if event.start > now && event.start < horizon {
            let slot = if event.start < tomorrow { &mut later_today } else { &mut this_week };

            if earliest(*slot, event) {
                *slot = Some(event);
            }
        }
    }

    ongoing_timed.or(later_today).or(ongoing_all_day).or(this_week)
}

// the other events today that aren't over yet, beside the one the bar shows
pub fn others_today(events: &[Event], shown: &Event, now: i64, offset: i64) -> usize {
    today(events, now, offset)
        .into_iter()
        .filter(|event| event.end > now && *event != shown)
        .count()
}

// everything on today, finished or not: all-day first, then by start
pub fn today(events: &[Event], now: i64, offset: i64) -> Vec<&Event> {
    on_day(events, (now + offset).div_euclid(DAY), offset)
}

/*
 * the bar's countdown: "now" (or "today" for an all-day event), "in 18m"
 * up to half an hour, then "in 2h 10m", then the weekday, then the date
 */
pub fn countdown(event: &Event, now: i64, offset: i64) -> String {
    count(event, now, offset, false)
}

/*
 * the same for the bar, where a long wait reads as the time of day instead
 * ("at 7:30 PM", as in the bar's clock), so the text holds still until the event is close. the
 * dashboard keeps the exact countdown, as it lists the hours beside it
 */
pub fn glance(event: &Event, now: i64, offset: i64) -> String {
    count(event, now, offset, true)
}

fn count(event: &Event, now: i64, offset: i64, clock: bool) -> String {
    if event.start <= now {
        return String::from(if event.all_day { "today" } else { "now" });
    }

    let minutes = (event.start - now + 59) / 60;

    if minutes <= SOON {
        return format!("in {minutes}m");
    }

    if clock && minutes > FAR && minutes < 24 * 60 {
        let (time, period) = twelve_hour((event.start + offset).rem_euclid(DAY));

        return format!("at {time} {period}");
    }

    if minutes < 24 * 60 {
        return format!("in {}", duration(minutes));
    }

    let days = (event.start + offset).div_euclid(DAY);
    let days_away = days - (now + offset).div_euclid(DAY);

    if days_away <= 6 {
        return WEEKDAYS[days.rem_euclid(7) as usize].to_string();
    }

    let (_, month, day) = civil_date(days);

    format!("{} {day}", MONTHS[(month - 1) as usize])
}

// neue's EventTime.duration: "45m", "2h", "2h 10m", "3d"
pub fn duration(minutes: i64) -> String {
    if minutes < 60 {
        return format!("{minutes}m");
    }

    if minutes < 24 * 60 {
        let (hours, rest) = (minutes / 60, minutes % 60);

        return if rest == 0 {
            format!("{hours}h")
        } else {
            format!("{hours}h {rest}m")
        };
    }

    format!("{}d", (minutes + 24 * 60 - 1) / (24 * 60))
}

// "09:30", in local time
pub(super) fn clock_time(utc: i64, offset: i64) -> String {
    let seconds = (utc + offset).rem_euclid(DAY);

    format!("{:02}:{:02}", seconds / 3600, seconds % 3600 / 60)
}

#[cfg(test)]
mod tests {
    use super::*;

    // wednesday 2026-11-11, 10:00 at +05:30
    const OFFSET: i64 = 19_800;
    const MIDNIGHT: i64 = 1_794_355_200 - OFFSET;
    const NOW: i64 = MIDNIGHT + 10 * 3600;

    fn timed(title: &str, from_hours: f64, for_minutes: i64) -> Event {
        let start = MIDNIGHT + (from_hours * 3600.0) as i64;

        Event {
            start,
            end: start + for_minutes * 60,
            all_day: false,
            title: title.to_string(),
            uid: title.to_string(),
        }
    }

    fn all_day(title: &str, day: i64) -> Event {
        Event {
            start: MIDNIGHT + day * DAY,
            end: MIDNIGHT + (day + 1) * DAY,
            all_day: true,
            title: title.to_string(),
            uid: title.to_string(),
        }
    }

    #[test]
    fn a_meeting_today_beats_a_holiday_going_on() {
        let events = [all_day("holiday", 0), timed("standup", 10.25, 15)];

        assert_eq!(next(&events, NOW, OFFSET).map(|e| e.title.as_str()), Some("standup"));
    }

    #[test]
    fn something_on_now_comes_first() {
        let events = [timed("standup", 10.25, 15), timed("review", 9.5, 60)];

        assert_eq!(next(&events, NOW, OFFSET).map(|e| e.title.as_str()), Some("review"));
    }

    #[test]
    fn a_holiday_beats_tomorrow() {
        let events = [all_day("holiday", 0), timed("dentist", 24.0 + 9.0, 30)];

        assert_eq!(next(&events, NOW, OFFSET).map(|e| e.title.as_str()), Some("holiday"));
    }

    #[test]
    fn looks_a_week_ahead_and_no_further() {
        let soon = [timed("trip", 24.0 * 7.0 + 9.0, 60)];
        let far = [timed("trip", 24.0 * 8.0 + 9.0, 60)];

        assert!(next(&soon, NOW, OFFSET).is_some());
        assert!(next(&far, NOW, OFFSET).is_none());
        assert!(next(&[timed("done", 8.0, 60)], NOW, OFFSET).is_none());
    }

    #[test]
    fn counts_the_rest_of_today() {
        let events = [
            timed("breakfast", 8.0, 30),
            timed("standup", 10.25, 15),
            timed("review", 14.0, 60),
            timed("gym", 18.0, 60),
            timed("tomorrow", 24.0 + 9.0, 60),
        ];

        let shown = next(&events, NOW, OFFSET).unwrap();

        assert_eq!(shown.title, "standup");
        assert_eq!(others_today(&events, shown, NOW, OFFSET), 2);
    }

    #[test]
    fn lists_today_with_all_day_first() {
        let events = [timed("gym", 18.0, 60), all_day("holiday", 0), timed("standup", 10.25, 15), all_day("tomorrow", 1)];

        let titles: Vec<&str> = today(&events, NOW, OFFSET).iter().map(|e| e.title.as_str()).collect();

        assert_eq!(titles, ["holiday", "standup", "gym"]);
    }

    #[test]
    fn counts_down_like_neue() {
        let at = |hours: f64| countdown(&timed("x", hours, 30), NOW, OFFSET);

        assert_eq!(at(9.5), "now");
        assert_eq!(countdown(&all_day("x", 0), NOW, OFFSET), "today");
        assert_eq!(at(10.0 + 18.0 / 60.0), "in 18m");
        assert_eq!(at(10.5), "in 30m");
        assert_eq!(at(11.0), "in 1h");
        assert_eq!(at(12.0 + 10.0 / 60.0), "in 2h 10m");
        // friday the 13th, tuesday the 17th, then past the week a date
        assert_eq!(at(24.0 * 2.0 + 9.0), "fri");
        assert_eq!(at(24.0 * 6.0 + 9.0), "tue");
        assert_eq!(at(24.0 * 10.0 + 9.0), "nov 21");
    }

    #[test]
    fn the_bar_shows_the_time_of_day_when_far() {
        let at = |hours: f64| glance(&timed("x", hours, 30), NOW, OFFSET);

        assert_eq!(at(10.0 + 18.0 / 60.0), "in 18m");
        assert_eq!(at(12.0 + 10.0 / 60.0), "in 2h 10m");
        assert_eq!(at(13.0), "in 3h");
        assert_eq!(at(13.0 + 1.0 / 60.0), "at 1:01 PM");
        assert_eq!(at(19.5), "at 7:30 PM");
        assert_eq!(at(24.0 + 0.5), "at 12:30 AM");
        assert_eq!(at(24.0 * 2.0 + 9.0), "fri");
    }

    #[test]
    fn rounds_a_part_minute_up() {
        let event = Event {
            start: NOW + 61,
            ..timed("x", 0.0, 30)
        };

        assert_eq!(countdown(&event, NOW, OFFSET), "in 2m");
    }

    #[test]
    fn writes_durations() {
        assert_eq!(duration(45), "45m");
        assert_eq!(duration(120), "2h");
        assert_eq!(duration(130), "2h 10m");
        assert_eq!(duration(24 * 60 + 1), "2d");
    }
}
