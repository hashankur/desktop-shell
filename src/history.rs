mod store;

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::thread;
use std::time::{Duration, SystemTime};

use amane::{Notifications, Service};

use crate::files;
use crate::theme::{self, history};

// how often the live list is compared with what is kept; it can't be waited on
const POLL: Duration = Duration::from_millis(500);

// one write at a time, so two threads never fight over the file beside the real one
static SAVING: Mutex<()> = Mutex::new(());

/*
 * a notification as it is kept: what is shown of it, and nothing that only
 * works while its sender is still there, like its buttons
 */
#[derive(Clone, Debug, PartialEq)]
pub struct Saved {
    // told apart from the others while the shell runs; Amane's ids start over each time
    pub key: u64,
    pub app: String,
    pub summary: String,
    pub body: String,
    pub icon: String,
    pub image: String,
    pub received: SystemTime,
    // the id it has in this run's live list; none for one kept from an earlier run
    pub live: Option<u32>,
}

/*
 * notifications kept across restarts, in state. Amane's list lives in its
 * process and nothing can be put back into it, so this keeps a copy of every
 * live notification as it arrives, and gives it up when it is dismissed. a
 * restart leaves the copies behind, and they come back as "restored": shown
 * in the dashboard and counted, but with no buttons to press. they go after
 * a few days
 */
#[derive(Default)]
pub struct History {
    // oldest first
    entries: Vec<Saved>,
    next: u64,
}

impl Service for History {
    fn new() -> Self {
        let now = SystemTime::now();

        let mut entries = fs::read_to_string(path())
            .map(|text| store::decode(&text))
            .unwrap_or_default();

        entries.retain(|entry| !store::expired(entry.received, now));

        for (index, entry) in entries.iter_mut().enumerate() {
            entry.key = index as u64 + 1;

            // an avatar Amane saved is gone if the machine restarted since
            if !entry.image.is_empty() && !exists(&entry.image) {
                entry.image.clear();
            }
        }

        let next = entries.len() as u64 + 1;

        Self { entries, next }
    }

    fn listen() {
        loop {
            thread::sleep(POLL);

            sync();
        }
    }
}

// the ones kept from before this run, newest first
pub fn restored() -> Vec<Saved> {
    History::read()
        .entries
        .iter()
        .rev()
        .filter(|entry| entry.live.is_none())
        .cloned()
        .collect()
}

pub fn restored_count() -> usize {
    History::read().entries.iter().filter(|entry| entry.live.is_none()).count()
}

// a restored one dismissed
pub fn dismiss(key: u64) {
    remove(|entry| entry.key == key);
}

// a live one dismissed, so a restart right after doesn't bring it back
pub fn forget(id: u32) {
    remove(|entry| entry.live == Some(id));
}

// everything, live and restored
pub fn clear_all() {
    Notifications::clear();

    remove(|_| true);
}

fn remove(gone: impl Fn(&Saved) -> bool) {
    if !History::read().entries.iter().any(&gone) {
        return;
    }

    History::write().entries.retain(|entry| !gone(entry));

    save();
}

// compares before writing: a write redraws every window that reads the service
fn sync() {
    let seen: Vec<Saved> = Notifications::read()
        .list()
        .iter()
        .map(|note| Saved {
            key: 0,
            app: note.app_name().to_string(),
            summary: note.summary().to_string(),
            body: note.body().to_string(),
            icon: note.icon().to_string(),
            image: note.image().to_string(),
            received: note.received(),
            live: Some(note.id()),
        })
        .collect();

    let now = SystemTime::now();

    let (mut entries, mut next) = {
        let history = History::read();

        (history.entries.clone(), history.next)
    };

    if !mirror(&mut entries, &mut next, &seen, now) {
        return;
    }

    // done again on the real list, in case a dismiss came in since it was copied
    {
        let mut history = History::write();
        let History { entries, next } = &mut *history;

        mirror(entries, next, &seen, now);
    }

    save();
}

/*
 * brings the kept list in line with the live one: new ones are added, one
 * its sender replaced is updated in place, one that is gone from the live
 * list is dropped, and a restored one past its days or over the cap goes.
 * says whether anything changed
 */
fn mirror(entries: &mut Vec<Saved>, next: &mut u64, seen: &[Saved], now: SystemTime) -> bool {
    let before = entries.clone();

    for live in seen {
        match entries.iter_mut().find(|entry| entry.live == live.live) {
            Some(entry) => {
                let key = entry.key;

                *entry = Saved { key, ..live.clone() };
            }

            None => {
                entries.push(Saved { key: *next, ..live.clone() });

                *next += 1;
            }
        }
    }

    entries.retain(|entry| match entry.live {
        Some(id) => seen.iter().any(|live| live.live == Some(id)),
        None => !store::expired(entry.received, now),
    });

    while entries.len() > history::MAX {
        let Some(oldest) = entries.iter().position(|entry| entry.live.is_none()) else {
            break;
        };

        entries.remove(oldest);
    }

    *entries != before
}

fn save() {
    let _one_at_a_time = SAVING.lock().unwrap_or_else(|poisoned| poisoned.into_inner());

    let text = store::encode(&History::read().entries);

    // private: it holds what people wrote to the user
    let _ = files::write_private(&path(), &text);
}

fn exists(image: &str) -> bool {
    let image = image.trim();

    Path::new(image.strip_prefix("file://").unwrap_or(image)).exists()
}

fn path() -> PathBuf {
    theme::state_folder().join("notifications")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn note(id: Option<u32>, summary: &str, received: SystemTime) -> Saved {
        Saved {
            key: 0,
            app: String::from("signal"),
            summary: String::from(summary),
            body: String::new(),
            icon: String::new(),
            image: String::new(),
            received,
            live: id,
        }
    }

    #[test]
    fn a_new_live_one_is_kept_and_a_replaced_one_updated_in_place() {
        let now = SystemTime::now();
        let (mut entries, mut next) = (Vec::new(), 1);

        assert!(mirror(&mut entries, &mut next, &[note(Some(1), "hi", now)], now));
        assert_eq!(entries.len(), 1);

        // nothing changed, so nothing is written
        assert!(!mirror(&mut entries, &mut next, &[note(Some(1), "hi", now)], now));

        assert!(mirror(&mut entries, &mut next, &[note(Some(1), "hi again", now)], now));
        assert_eq!((entries.len(), entries[0].summary.as_str(), entries[0].key), (1, "hi again", 1));
    }

    #[test]
    fn one_gone_from_the_live_list_is_dropped_but_a_restored_one_stays() {
        let now = SystemTime::now();
        let mut next = 3;

        let mut entries = vec![
            Saved { key: 1, ..note(None, "old", now) },
            Saved { key: 2, ..note(Some(1), "live", now) },
        ];

        assert!(mirror(&mut entries, &mut next, &[], now));

        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].summary, "old");
    }

    #[test]
    fn a_restored_one_expires_but_a_live_one_does_not() {
        let now = SystemTime::now();
        let old = now - Duration::from_secs(history::KEEP_DAYS * 24 * 3600 + 60);
        let mut next = 3;

        let mut entries = vec![
            Saved { key: 1, ..note(None, "old", old) },
            Saved { key: 2, ..note(Some(7), "live and old", old) },
        ];

        mirror(&mut entries, &mut next, &[note(Some(7), "live and old", old)], now);

        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].live, Some(7));
    }

    #[test]
    fn restored_ones_are_dropped_oldest_first_past_the_cap() {
        let now = SystemTime::now();
        let mut next = 1;

        let mut entries: Vec<Saved> = (0..history::MAX + 2)
            .map(|index| Saved { key: index as u64, ..note(None, &index.to_string(), now) })
            .collect();

        mirror(&mut entries, &mut next, &[], now);

        assert_eq!(entries.len(), history::MAX);
        assert_eq!(entries[0].summary, "2");
    }
}
