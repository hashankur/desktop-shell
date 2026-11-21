use amane::Notifications;

use crate::history;
use crate::surface::Surface;

/*
 * which notification a row stands for: one in Amane's live list, which has
 * its sender behind it, or one kept from an earlier run, which has not
 */
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Handle {
    Live(u32),
    Saved(u64),
}

impl Handle {
    // for hover keys, which must not mix a live id with a kept one
    pub fn tag(self) -> String {
        match self {
            Self::Live(id) => format!("live-{id}"),
            Self::Saved(key) => format!("saved-{key}"),
        }
    }

    // a live one runs its default action and closes the dashboard; a kept one has none, so it just goes
    pub fn click(self) {
        match self {
            Self::Live(id) => {
                Notifications::click(id);
                Surface::close();
            }

            Self::Saved(key) => history::dismiss(key),
        }
    }

    pub fn dismiss(self) {
        match self {
            Self::Live(id) => {
                Notifications::dismiss(id);
                history::forget(id);
            }

            Self::Saved(key) => history::dismiss(key),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_live_id_and_a_kept_key_never_share_a_tag() {
        assert_ne!(Handle::Live(3).tag(), Handle::Saved(3).tag());
    }
}
