use super::Event;
use super::agenda::{WEEKDAYS, clock_time};
use super::time::DAY;
use crate::clock::{civil_date, days_from_civil};

/*
 * the month and the agenda in local days, counted since 1970 like
 * Clock::days, so a day is the same number in the grid and in the list
 */

// six weeks, so the month's grid is the same height whichever month it shows
pub const GRID_DAYS: i64 = 42;

// 0 is monday; 1970-01-01 was a thursday
pub fn weekday(day: i64) -> i64 {
    (day + 3).rem_euclid(7)
}

// the first day a month's grid shows: the monday on or before its first
pub fn grid_start(year: i64, month: i64) -> i64 {
    let first = days_from_civil(year, month, 1);

    first - weekday(first)
}

// the month `by` months from another, across the turn of a year either way
pub fn shift_month(year: i64, month: i64, by: i64) -> (i64, i64) {
    let index = year * 12 + (month - 1) + by;

    (index.div_euclid(12), index.rem_euclid(12) + 1)
}

// everything on a local day, finished or not: all-day first, then by start
pub fn on_day(events: &[Event], day: i64, offset: i64) -> Vec<&Event> {
    let start = day * DAY - offset;
    let end = start + DAY;

    let mut on: Vec<&Event> = events
        .iter()
        .filter(|event| event.start < end && event.end > start)
        .collect();

    on.sort_by(|a, b| b.all_day.cmp(&a.all_day).then(a.start.cmp(&b.start)));

    on
}

/*
 * today, then the next days that have something on, up to `ahead` days
 * out. today is always there, even empty, so a quiet day says so instead
 * of the list starting at some later date. `also` says whether a day has
 * something besides events, like a task due
 */
pub fn upcoming(
    events: &[Event],
    today: i64,
    ahead: i64,
    offset: i64,
    also: impl Fn(i64) -> bool,
) -> Vec<(i64, Vec<&Event>)> {
    (today..=today + ahead)
        .map(|day| (day, on_day(events, day, offset)))
        .filter(|(day, on)| *day == today || !on.is_empty() || also(*day))
        .collect()
}

/*
 * how many events touch each of `count` days from `first`, for the dots
 * under the month's numbers. one that runs over several days counts on
 * each; its end is exclusive, so a thing that ends at midnight isn't on
 * the next day
 */
pub fn per_day(events: &[Event], first: i64, count: i64, offset: i64) -> Vec<usize> {
    let mut counts = vec![0; count.max(0) as usize];

    for event in events {
        let from = (event.start + offset).div_euclid(DAY);
        let to = (event.end.max(event.start + 1) - 1 + offset).div_euclid(DAY);

        for day in from.max(first)..=to.min(first + count - 1) {
            if let Some(slot) = counts.get_mut((day - first) as usize) {
                *slot += 1;
            }
        }
    }

    counts
}

/*
 * an event's hours in a day's list: "13:00–14:00", "all day", and for one
 * that runs into or out of the day, the end it has there: "to 00:30" or
 * "from 23:00"
 */
pub fn hours(event: &Event, day: i64, offset: i64) -> String {
    let start = day * DAY - offset;
    let end = start + DAY;

    let before = event.start < start;
    let after = event.end > end;

    if event.all_day || (before && after) {
        return String::from("all day");
    }

    if before {
        return format!("to {}", clock_time(event.end, offset));
    }

    if after {
        return format!("from {}", clock_time(event.start, offset));
    }

    format!(
        "{}–{}",
        clock_time(event.start, offset),
        clock_time(event.end, offset)
    )
}

// a day's heading in the agenda: "today", "tomorrow · fri 13", then "sat 14"
pub fn heading(day: i64, today: i64) -> String {
    let weekday = WEEKDAYS
        .get(day.rem_euclid(7) as usize)
        .copied()
        .unwrap_or_default();

    let (_, _, date) = civil_date(day);

    match day - today {
        0 => String::from("today"),
        1 => format!("tomorrow · {weekday} {date}"),
        _ => format!("{weekday} {date}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // +05:30, and thursday 2026-11-12 as a local day
    const OFFSET: i64 = 19_800;

    fn day(year: i64, month: i64, date: i64) -> i64 {
        days_from_civil(year, month, date)
    }

    fn timed(title: &str, on: i64, from_hours: f64, for_minutes: i64) -> Event {
        let start = on * DAY - OFFSET + (from_hours * 3600.0) as i64;

        Event {
            start,
            end: start + for_minutes * 60,
            all_day: false,
            title: title.to_string(),
            uid: title.to_string(),
        }
    }

    fn all_day(title: &str, from: i64, days: i64) -> Event {
        Event {
            start: from * DAY - OFFSET,
            end: (from + days) * DAY - OFFSET,
            all_day: true,
            title: title.to_string(),
            uid: title.to_string(),
        }
    }

    #[test]
    fn grids_start_on_the_monday_before_the_first() {
        // november 2026 starts on a sunday, so its grid starts in october
        assert_eq!(grid_start(2026, 11), day(2026, 10, 26));
        // june 2026 starts on a monday, which is the grid's first day
        assert_eq!(grid_start(2026, 6), day(2026, 6, 1));
        assert_eq!(weekday(grid_start(2027, 1)), 0);
    }

    #[test]
    fn months_shift_across_years() {
        assert_eq!(shift_month(2026, 12, 1), (2027, 1));
        assert_eq!(shift_month(2027, 1, -1), (2026, 12));
        assert_eq!(shift_month(2026, 11, -23), (2024, 12));
        assert_eq!(shift_month(2026, 11, 0), (2026, 11));
    }

    #[test]
    fn counts_a_long_event_on_every_day_it_covers() {
        let today = day(2026, 11, 12);
        let events = [
            all_day("trip", today, 3),
            timed("standup", today, 9.5, 30),
            // late last night into today
            timed("late", today - 1, 23.0, 90),
            // ends exactly at midnight, so not on the next day
            timed("evening", today + 3, 22.0, 120),
        ];

        assert_eq!(per_day(&events, today - 1, 6, OFFSET), [1, 3, 1, 1, 1, 0]);
    }

    #[test]
    fn writes_an_events_hours_for_its_day() {
        let today = day(2026, 11, 12);

        assert_eq!(hours(&timed("x", today, 13.0, 60), today, OFFSET), "13:00–14:00");
        assert_eq!(hours(&all_day("x", today, 1), today, OFFSET), "all day");
        assert_eq!(hours(&timed("x", today - 1, 23.0, 90), today, OFFSET), "to 00:30");
        assert_eq!(hours(&timed("x", today, 23.0, 90), today, OFFSET), "from 23:00");
        assert_eq!(hours(&timed("x", today - 1, 12.0, 48 * 60), today, OFFSET), "all day");
    }

    #[test]
    fn lists_today_then_the_next_days_with_something_on() {
        let today = day(2026, 11, 12);
        let events = [
            timed("review", today + 1, 13.0, 60),
            timed("dentist", today + 3, 9.0, 30),
            timed("far", today + 9, 9.0, 30),
        ];

        let days: Vec<i64> = upcoming(&events, today, 7, OFFSET, |day| day == today + 5)
            .iter()
            .map(|(day, _)| day - today)
            .collect();

        assert_eq!(days, [0, 1, 3, 5]);
    }

    #[test]
    fn heads_each_day() {
        let today = day(2026, 11, 12);

        assert_eq!(heading(today, today), "today");
        assert_eq!(heading(today + 1, today), "tomorrow · fri 13");
        assert_eq!(heading(today + 2, today), "sat 14");
    }
}
