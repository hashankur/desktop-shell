use amane::Service;

use super::days::{GRID_DAYS, grid_start};
use super::time::DAY;
use super::{Calendar, api, now};
use crate::clock;

/*
 * a month the dashboard browsed to: the six weeks its grid shows. a failed
 * fetch leaves the month without dots; the main fetch is the one that
 * reports problems. google gives up to 250 events per calendar for the
 * window and nothing here asks for the next page, which six weeks of even a
 * busy calendar stays under
 */
pub fn fetch(year: i64, month: i64) {
    let offset = clock::read_offset();
    let first = grid_start(year, month);

    let (from, to) = (first * DAY - offset, (first + GRID_DAYS) * DAY - offset);

    let Ok(events) = api::events(from, to, now(), offset) else {
        return;
    };

    if Calendar::read().months.get(&(year, month)) == Some(&events) {
        return;
    }

    Calendar::write().months.insert((year, month), events);
}
