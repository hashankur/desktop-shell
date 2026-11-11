pub mod agenda;
mod encode;
mod google;
mod login;
mod store;
mod time;

use std::path::PathBuf;
use std::sync::{Condvar, Mutex, PoisonError};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use amane::Service;

use crate::clock;
use store::Credentials;

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
 * the coming week from google calendar. it starts with the events the last
 * fetch saved, and a failed fetch keeps them: stale beats empty. nothing
 * shows anywhere until the user signs in
 */
#[derive(Default)]
pub struct Calendar {
    events: Vec<Event>,
    signed_in: bool,
}

impl Service for Calendar {
    fn new() -> Self {
        let signed_in = Credentials::load().is_some_and(|credentials| credentials.signed_in());

        Self {
            events: if signed_in { store::load_events() } else { Vec::new() },
            signed_in,
        }
    }

    /*
     * fetches when the saved events are older than the refresh interval, so
     * a restart doesn't fetch again, then every interval, or straight away
     * when woken by a sign-in or the dashboard opening
     */
    fn listen() {
        let mut due = store::fetched_at()
            .and_then(|at| at.elapsed().ok())
            .is_none_or(|age| age >= REFRESH);

        loop {
            if due {
                fetch();
            }

            let (lock, signal) = &WAKE;
            let woken = lock.lock().unwrap_or_else(PoisonError::into_inner);

            let (mut woken, _) = signal
                .wait_timeout_while(woken, REFRESH, |woken| !*woken)
                .unwrap_or_else(PoisonError::into_inner);

            *woken = false;
            due = true;
        }
    }
}

impl Calendar {
    pub fn events(&self) -> &[Event] {
        &self.events
    }

    pub fn signed_in(&self) -> bool {
        self.signed_in
    }
}

static WAKE: (Mutex<bool>, Condvar) = (Mutex::new(false), Condvar::new());

/*
 * why the last fetch failed and when, until one succeeds. kept out of the
 * service, since nothing on screen shows it; the ipc status does
 */
static PROBLEM: Mutex<Option<(i64, &'static str)>> = Mutex::new(None);

fn wake() {
    let (lock, signal) = &WAKE;

    *lock.lock().unwrap_or_else(PoisonError::into_inner) = true;
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

// from today's local midnight to the end of the coming week, on google's calendars
fn fetch() {
    let Some(mut credentials) = Credentials::load().filter(Credentials::signed_in) else {
        return;
    };

    let (now, offset) = (now(), clock::read_offset());
    let from = time::midnight(now, offset);
    let to = from + (agenda::AHEAD + 1) * time::DAY;

    let events = match google::events(&mut credentials, from, to, now, offset) {
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

fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or(Duration::ZERO)
        .as_secs() as i64
}

// a finished sign-in: the views can start showing events, and the first fetch goes now
fn signed_in() {
    if !Calendar::read().signed_in {
        Calendar::write().signed_in = true;
    }

    wake();
}

fn sign_out() {
    Credentials::forget();
    store::forget_events();

    *PROBLEM.lock().unwrap_or_else(PoisonError::into_inner) = None;

    let mut calendar = Calendar::write();

    calendar.events.clear();
    calendar.signed_in = false;
}

/*
 * `amane ipc call calendar login <client.json>` signs in to google with a
 * desktop client's json; `logout` forgets the tokens and events; `refresh`
 * fetches now; no argument says whether it is signed in
 */
pub fn ipc(arguments: &[String]) -> String {
    match arguments.first().map(String::as_str) {
        Some("login") => {
            let Some(path) = arguments.get(1) else {
                return String::from("usage: calendar login <path to the client json from google cloud>");
            };

            // the shell runs elsewhere, so a path from the caller's shell has to stand on its own
            let path = match (path.strip_prefix("~/"), std::env::var_os("HOME")) {
                (Some(rest), Some(home)) => PathBuf::from(home).join(rest),
                _ => PathBuf::from(path),
            };

            if path.is_relative() {
                return String::from("give the client json's full path");
            }

            match login::start(&path) {
                Ok(()) => String::from("finish signing in in the browser"),
                Err(error) => error,
            }
        }

        Some("logout") => {
            sign_out();

            String::from("signed out")
        }

        Some("refresh") => {
            wake();

            String::from("fetching")
        }

        _ => {
            let calendar = Calendar::read();

            if !calendar.signed_in {
                return String::from("signed out; sign in with `calendar login <client.json>`");
            }

            let mut status = format!("signed in, {} events this week", calendar.events.len());
            drop(calendar);

            if let Some((at, problem)) = *PROBLEM.lock().unwrap_or_else(PoisonError::into_inner) {
                let minutes = (now() - at).max(0) / 60;

                status.push_str(&format!("\nlast fetch failed {minutes} min ago: {problem}"));
            }

            status
        }
    }
}
