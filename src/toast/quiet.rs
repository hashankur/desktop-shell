use std::fs;
use std::path::PathBuf;

use amane::Service;

use crate::files;
use crate::theme;

/*
 * do not disturb: while it's on only critical notifications show as toasts.
 * the rest still arrive and are counted, so the bar and the dashboard have
 * them. it is kept in state, so a restart doesn't quietly turn it off
 */
#[derive(Default)]
pub struct Quiet {
    on: bool,
}

impl Service for Quiet {
    fn new() -> Self {
        Self {
            on: fs::read_to_string(path()).is_ok_and(|text| text.trim() == "on"),
        }
    }

    // only changes through settings
    fn listen() {}
}

impl Quiet {
    pub fn on(&self) -> bool {
        self.on
    }

    pub fn toggle() {
        let on = !Self::read().on;

        Self::write().on = on;

        let _ = files::write_atomic(&path(), if on { "on\n" } else { "off\n" });
    }
}

fn path() -> PathBuf {
    theme::state_folder().join("quiet")
}
