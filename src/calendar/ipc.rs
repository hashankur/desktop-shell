use std::path::PathBuf;
use std::sync::PoisonError;

use amane::Service;

use super::{Calendar, PROBLEM, now, sign_out, wake};
use crate::google::login;

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

            match login(&path) {
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

            let mut status = format!("signed in, {} events this month and week", calendar.events.len());
            drop(calendar);

            if let Some((at, problem)) = *PROBLEM.lock().unwrap_or_else(PoisonError::into_inner) {
                let minutes = (now() - at).max(0) / 60;

                status.push_str(&format!("\nlast fetch failed {minutes} min ago: {problem}"));
            }

            status
        }
    }
}
