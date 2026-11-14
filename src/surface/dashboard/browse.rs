use amane::{Key, Service};

use crate::calendar;
use crate::calendar::days::shift_month;
use crate::clock::{Clock, civil_date};

/*
 * how many months from this one the month shows. only one surface is open
 * at a time, so this starts over on this month every time the dashboard opens
 */
#[derive(Default)]
pub struct Browse {
    months: i64,
}

impl Service for Browse {
    fn new() -> Self {
        Self::default()
    }

    // only changes through keys and clicks
    fn listen() {}
}

pub fn reset() {
    if Browse::read().months != 0 {
        Browse::write().months = 0;
    }
}

// the year and month on screen
pub fn shown() -> (i64, i64) {
    let months = Browse::read().months;
    let (year, month, _) = civil_date(Clock::read().days());

    shift_month(year, month, months)
}

// whether the month on screen is this one
pub fn at_today() -> bool {
    Browse::read().months == 0
}

pub fn step(by: i64) {
    let months = Browse::read().months + by;

    go(months);
}

pub fn today() {
    go(0);
}

// another month asks the calendar for its events; this month's come with the main fetch
fn go(months: i64) {
    if Browse::read().months == months {
        return;
    }

    Browse::write().months = months;

    if months != 0 {
        let (year, month) = shown();

        calendar::want_month(year, month);
    }
}

// left and right move a month, home comes back to this one
pub fn key(key: Key) {
    match key {
        Key::Left => step(-1),
        Key::Right => step(1),
        Key::Home => today(),
        _ => {}
    }
}
