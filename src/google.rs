mod credentials;
pub mod encode;
mod http;
mod login;

use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub use credentials::Credentials;
pub use http::{access_token, get, jq, run, send};
pub use login::start as login;

/*
 * signing in to google and talking to its apis, shared by everything that
 * reads the account: one sign-in, one set of tokens in state
 */

pub const CALENDAR: &str = "https://www.googleapis.com/auth/calendar.readonly";
pub const TASKS: &str = "https://www.googleapis.com/auth/tasks";

// what a sign-in asks for: reading the calendar, and reading and changing tasks
const SCOPES: [&str; 2] = [CALENDAR, TASKS];

pub fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or(Duration::ZERO)
        .as_secs() as i64
}

// a finished sign-in, told to everything that waits on one
fn signed_in() {
    crate::calendar::signed_in();
    crate::tasks::signed_in();
}
