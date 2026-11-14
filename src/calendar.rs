pub mod agenda;
pub mod days;
mod api;
mod ipc;
mod months;
mod store;
mod time;

use std::collections::HashMap;
use std::sync::{Condvar, Mutex, PoisonError};
use std::time::Duration;

use amane::Service;

use crate::clock;
use crate::google::{Credentials, now};

pub use ipc::ipc;

// how often events are fetched again
const REFRESH: Duration = Duration::from_secs(15 * 60);

// opening the dashboard fetches again if the last fetch is older than this
const STALE: Duration = Duration::from_secs(5 * 60);

// one event, or one day of a repeating one: google expands repeats itself
#[derive(Clone, Debug, PartialEq)]
pub struct Event {
    // seconds since 1970 in utc; an all-day event runs from local midnight to the next
    pub start: i64,
    pub end: i64,
    pub all_day: bool,
    pub title: String,
    // google's ical uid, the same on every calendar an invite reached
    pub uid: String,
}

/*
 * this month and the coming week from google calendar. it starts with the
 * events the last fetch saved, and a failed fetch keeps them: stale beats
 * empty. nothing shows anywhere until the user signs in
 */
#[derive(Default)]
pub struct Calendar {
    events: Vec<Event>,
    signed_in: bool,

    /*
     * other months the dashboard browsed to, by year and month, kept apart
     * so a browse never changes what the bar counts down to. only for this
     * run: they are fetched again whenever they are shown
     */
    months: HashMap<(i64, i64), Vec<Event>>,
}

impl Service for Calendar {
    fn new() -> Self {
        let signed_in = Credentials::load().is_some_and(|credentials| credentials.signed_in());

        Self {
            events: if signed_in { store::load_events() } else { Vec::new() },
            signed_in,
            months: HashMap::new(),
        }
    }

    /*
     * fetches when the saved events are older than the refresh interval, so
     * a restart doesn't fetch again, then every interval, or straight away
     * when woken by a sign-in or the dashboard opening. a month the
     * dashboard asks for is fetched here too, one at a time, since they
     * share the one wake-up
     */
    fn listen() {
        let mut asked = Asked {
            main: store::fetched_at()
                .and_then(|at| at.elapsed().ok())
                .is_none_or(|age| age >= REFRESH),
            month: None,
        };

        loop {
            if asked.main {
                fetch();
            }

            if let Some((year, month)) = asked.month {
                months::fetch(year, month);
            }

            let (lock, signal) = &WAKE;
            let waiting = lock.lock().unwrap_or_else(PoisonError::into_inner);

            let (mut waiting, timeout) = signal
                .wait_timeout_while(waiting, REFRESH, |asked| !asked.main && asked.month.is_none())
                .unwrap_or_else(PoisonError::into_inner);

            asked = std::mem::take(&mut *waiting);

            if timeout.timed_out() {
                asked.main = true;
            }
        }
    }
}

impl Calendar {
    pub fn events(&self) -> &[Event] {
        &self.events
    }

    // the events to show for a month: a browsed month's own, or the main ones for this month
    pub fn month(&self, year: i64, month: i64) -> &[Event] {
        self.months.get(&(year, month)).map_or(&self.events, Vec::as_slice)
    }

    pub fn signed_in(&self) -> bool {
        self.signed_in
    }
}

// what the fetching thread is asked to do when it wakes
#[derive(Default)]
struct Asked {
    main: bool,
    month: Option<(i64, i64)>,
}

static WAKE: (Mutex<Asked>, Condvar) = (
    Mutex::new(Asked {
        main: false,
        month: None,
    }),
    Condvar::new(),
);

/*
 * why the last fetch failed and when, until one succeeds. kept out of the
 * service, since nothing on screen shows it; the ipc status does
 */
static PROBLEM: Mutex<Option<(i64, &'static str)>> = Mutex::new(None);

fn wake() {
    let (lock, signal) = &WAKE;

    lock.lock().unwrap_or_else(PoisonError::into_inner).main = true;
    signal.notify_one();
}

/*
 * asks for a month the dashboard moved to, on the fetching thread. the
 * latest ask wins, so paging quickly past a few months only fetches the
 * one that stays on screen
 */
pub fn want_month(year: i64, month: i64) {
    if !Calendar::read().signed_in {
        return;
    }

    let (lock, signal) = &WAKE;

    lock.lock().unwrap_or_else(PoisonError::into_inner).month = Some((year, month));
    signal.notify_one();
}

// asks for a fetch when the dashboard opens, unless one happened recently
pub fn refresh_if_stale() {
    let stale = store::fetched_at()
        .and_then(|at| at.elapsed().ok())
        .is_none_or(|age| age >= STALE);

    if stale && Calendar::read().signed_in {
        wake();
    }
}

/*
 * this month's grid in the dashboard and the coming week for the bar, on
 * google's calendars: from whichever starts first to whichever ends last.
 * the bar's lookups all filter by time, so the wider window doesn't change them.
 * google gives up to 250 events per calendar, oldest first, and nothing here
 * asks for the next page: a calendar busier than that over these five or six
 * weeks would lose its latest events, the ones the bar counts down to
 */
fn fetch() {
    if !Credentials::load().is_some_and(|credentials| credentials.signed_in()) {
        return;
    }

    let (now, offset) = (now(), clock::read_offset());

    let today = (now + offset).div_euclid(time::DAY);
    let (year, month, _) = clock::civil_date(today);
    let grid = days::grid_start(year, month);

    let first = grid.min(today);
    let last = (grid + days::GRID_DAYS).max(today + agenda::AHEAD + 1);

    let (from, to) = (first * time::DAY - offset, last * time::DAY - offset);

    let events = match api::events(from, to, now, offset) {
        Ok(events) => events,

        Err(problem) => {
            *PROBLEM.lock().unwrap_or_else(PoisonError::into_inner) = Some((now, problem));
            return;
        }
    };

    *PROBLEM.lock().unwrap_or_else(PoisonError::into_inner) = None;

    store::save_events(&events);

    let calendar = Calendar::read();
    let changed = calendar.events != events || !calendar.signed_in;
    drop(calendar);

    if changed {
        let mut calendar = Calendar::write();

        calendar.events = events;
        calendar.signed_in = true;
    }
}

// a finished sign-in: the views can start showing events, and the first fetch goes now
pub fn signed_in() {
    if !Calendar::read().signed_in {
        Calendar::write().signed_in = true;
    }

    wake();
}

fn sign_out() {
    Credentials::forget();
    crate::tasks::sign_out();
    store::forget_events();

    *PROBLEM.lock().unwrap_or_else(PoisonError::into_inner) = None;

    let mut calendar = Calendar::write();

    calendar.events.clear();
    calendar.months.clear();
    calendar.signed_in = false;
}
