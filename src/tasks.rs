mod api;
pub mod due;
mod ipc;
mod store;

use std::collections::VecDeque;
use std::sync::{Condvar, Mutex, PoisonError};
use std::time::Duration;

use amane::Service;

use crate::google::{self, Credentials, now};

pub use ipc::ipc;

// how often tasks are fetched again
const REFRESH: Duration = Duration::from_secs(15 * 60);

// opening the dashboard fetches again if the last fetch is older than this
const STALE: Duration = Duration::from_secs(5 * 60);

// a task added here that google hasn't given an id yet
const LOCAL: &str = "local:";

#[derive(Clone, Debug, PartialEq)]
pub struct List {
    pub id: String,
    pub title: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Task {
    pub id: String,
    // the id of the list it's in
    pub list: String,
    pub title: String,
    // a local day, like Clock::days; none for a task without a date
    pub due: Option<i64>,
    // google's order within the list, as text that sorts
    pub position: String,
    /*
     * ticked off here since the last fetch. a fetch only brings open
     * tasks, so a ticked one stays, ticked, until the next, and can be
     * unticked until then
     */
    pub done: bool,
}

/*
 * google tasks: every list and its open tasks. like the calendar it starts
 * with what the last fetch saved, and a failed fetch keeps it. changes
 * show at once and go to google on the fetching thread; one google turns
 * down is put right by fetching again. nothing shows until the user has
 * signed in with tasks allowed
 */
#[derive(Default)]
pub struct Tasks {
    lists: Vec<List>,
    tasks: Vec<Task>,
    ready: bool,
}

impl Service for Tasks {
    fn new() -> Self {
        let ready = allowed();
        let (lists, tasks) = if ready { store::load() } else { Default::default() };

        Self { lists, tasks, ready }
    }

    /*
     * sends the changes waiting, then fetches when asked or when the saved
     * tasks are older than the refresh interval, then every interval
     */
    fn listen() {
        let mut asked = Asked {
            fetch: store::fetched_at()
                .and_then(|at| at.elapsed().ok())
                .is_none_or(|age| age >= REFRESH),
            changes: VecDeque::new(),
        };

        loop {
            while let Some(change) = asked.changes.pop_front() {
                if !apply(change) {
                    asked.fetch = true;
                }
            }

            if asked.fetch {
                fetch();
            }

            let (lock, signal) = &WAKE;
            let waiting = lock.lock().unwrap_or_else(PoisonError::into_inner);

            let (mut waiting, timeout) = signal
                .wait_timeout_while(waiting, REFRESH, |asked| !asked.fetch && asked.changes.is_empty())
                .unwrap_or_else(PoisonError::into_inner);

            asked = std::mem::take(&mut *waiting);

            if timeout.timed_out() {
                asked.fetch = true;
            }
        }
    }
}

impl Tasks {
    pub fn ready(&self) -> bool {
        self.ready
    }

    pub fn lists(&self) -> &[List] {
        &self.lists
    }

    // open tasks, and ones ticked off since the last fetch, soonest due first
    pub fn tasks(&self) -> &[Task] {
        &self.tasks
    }

    // a list's name, for saying where a task is
    pub fn list_title(&self, id: &str) -> &str {
        self.lists
            .iter()
            .find(|list| list.id == id)
            .map_or("", |list| list.title.as_str())
    }

    // the list google's apps add to: the first one, "my tasks" unless renamed
    pub fn default_list(&self) -> Option<&List> {
        self.lists.first()
    }
}

// signed in, with tasks among what google granted
fn allowed() -> bool {
    Credentials::load().is_some_and(|credentials| credentials.signed_in() && credentials.granted(google::TASKS))
}

enum Change {
    Done { list: String, id: String, done: bool },
    Add { local: String, list: String, title: String, due: Option<i64> },
}

// what the fetching thread is asked to do when it wakes
#[derive(Default)]
struct Asked {
    fetch: bool,
    changes: VecDeque<Change>,
}

static WAKE: (Mutex<Asked>, Condvar) = (
    Mutex::new(Asked {
        fetch: false,
        changes: VecDeque::new(),
    }),
    Condvar::new(),
);

// why the last fetch or change failed and when, for the ipc status
static PROBLEM: Mutex<Option<(i64, &'static str)>> = Mutex::new(None);

// how many tasks have been added here, for their ids until google gives theirs
static ADDED: Mutex<u64> = Mutex::new(0);

fn ask(fetch: bool, change: Option<Change>) {
    let (lock, signal) = &WAKE;
    let mut asked = lock.lock().unwrap_or_else(PoisonError::into_inner);

    asked.fetch |= fetch;
    asked.changes.extend(change);

    drop(asked);
    signal.notify_one();
}

fn problem(what: Option<&'static str>) {
    *PROBLEM.lock().unwrap_or_else(PoisonError::into_inner) = what.map(|what| (now(), what));
}

/*
 * ticks a task off or back on. it shows at once and goes to google after.
 * a task added a moment ago waits for google's id before it can change
 */
pub fn toggle(id: &str) {
    if id.starts_with(LOCAL) {
        return;
    }

    let mut tasks = Tasks::write();

    let Some(task) = tasks.tasks.iter_mut().find(|task| task.id == id) else {
        return;
    };

    task.done = !task.done;

    let change = Change::Done {
        list: task.list.clone(),
        id: task.id.clone(),
        done: task.done,
    };

    drop(tasks);
    ask(false, Some(change));
}

// adds a task to a list; it shows at once, and google gives it its id after
pub fn add(list: &str, title: &str, due: Option<i64>) {
    let title = title.trim();

    if title.is_empty() || !Tasks::read().ready {
        return;
    }

    let local = {
        let mut added = ADDED.lock().unwrap_or_else(PoisonError::into_inner);
        *added += 1;

        format!("{LOCAL}{added}")
    };

    let mut tasks = Tasks::write();

    tasks.tasks.push(Task {
        id: local.clone(),
        list: list.to_string(),
        title: title.to_string(),
        due,
        // google puts a new task first in its list
        position: String::new(),
        done: false,
    });

    let lists = tasks.lists.clone();
    api::sort(&mut tasks.tasks, &lists);

    drop(tasks);

    ask(
        false,
        Some(Change::Add {
            local,
            list: list.to_string(),
            title: title.to_string(),
            due,
        }),
    );
}

// sends one change to google; false when it failed, which the next fetch puts right
fn apply(change: Change) -> bool {
    let result = match change {
        Change::Done { list, id, done } => api::set_done(&list, &id, done, now()),

        Change::Add { local, list, title, due } => api::add(&list, &title, due, now()).map(|id| {
            let mut tasks = Tasks::write();

            if let Some(task) = tasks.tasks.iter_mut().find(|task| task.id == local) {
                task.id = id;
            }
        }),
    };

    match result {
        Ok(()) => true,
        Err(what) => {
            problem(Some(what));
            false
        }
    }
}

/*
 * every list and open task. a fetch that lands while changes are still
 * waiting would undo them on screen, so it's dropped and asked for again
 * once they're sent
 */
fn fetch() {
    if !allowed() {
        if Tasks::read().ready {
            Tasks::write().ready = false;
        }

        return;
    }

    let (lists, tasks) = match api::everything(now()) {
        Ok(fetched) => fetched,
        Err(what) => {
            problem(Some(what));
            return;
        }
    };

    {
        let mut asked = WAKE.0.lock().unwrap_or_else(PoisonError::into_inner);

        if !asked.changes.is_empty() {
            asked.fetch = true;
            return;
        }
    }

    problem(None);
    store::save(&lists, &tasks);

    let current = Tasks::read();
    let changed = current.lists != lists || current.tasks != tasks || !current.ready;
    drop(current);

    if changed {
        *Tasks::write() = Tasks { lists, tasks, ready: true };
    }
}

// asks for a fetch when the dashboard opens, unless one happened recently
pub fn refresh_if_stale() {
    let stale = store::fetched_at()
        .and_then(|at| at.elapsed().ok())
        .is_none_or(|age| age >= STALE);

    if stale && Tasks::read().ready {
        ask(true, None);
    }
}

// a finished sign-in: tasks show once google says they're allowed, and the first fetch goes now
pub fn signed_in() {
    let ready = allowed();

    if Tasks::read().ready != ready {
        Tasks::write().ready = ready;
    }

    ask(true, None);
}

pub fn sign_out() {
    store::forget();
    problem(None);

    *Tasks::write() = Tasks::default();
}
