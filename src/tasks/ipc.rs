use std::sync::PoisonError;

use amane::Service;

use super::{PROBLEM, Tasks, allowed, ask};
use crate::google::{Credentials, now};

/*
 * `amane ipc call tasks refresh` fetches now; no argument says whether
 * tasks are there, and why not. signing in and out goes through the
 * calendar's ipc, since it's one google sign-in for both
 */
pub fn ipc(arguments: &[String]) -> String {
    // reading it first starts the service, and its thread, if nothing has yet
    drop(Tasks::read());

    if arguments.first().map(String::as_str) == Some("refresh") {
        ask(true, None);

        return String::from("fetching");
    }

    if !Credentials::load().is_some_and(|credentials| credentials.signed_in()) {
        return String::from("signed out; sign in with `calendar login <client.json>`");
    }

    if !allowed() {
        return String::from(
            "signed in without tasks; sign in again with `calendar login <client.json>` and allow tasks",
        );
    }

    let tasks = Tasks::read();
    let mut status = format!("{} open tasks in {} lists", tasks.tasks.len(), tasks.lists.len());
    drop(tasks);

    if let Some((at, problem)) = *PROBLEM.lock().unwrap_or_else(PoisonError::into_inner) {
        let minutes = (now() - at).max(0) / 60;

        status.push_str(&format!("\nlast fetch or change failed {minutes} min ago: {problem}"));
    }

    status
}
