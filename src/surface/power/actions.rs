use crate::compositor;
use crate::lock;

// what the surface offers, left to right
#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Action {
    Lock,
    Suspend,
    Logout,
    Reboot,
    Shutdown,
}

pub const ALL: [Action; 5] = [
    Action::Lock,
    Action::Suspend,
    Action::Logout,
    Action::Reboot,
    Action::Shutdown,
];

impl Action {
    pub fn label(self) -> &'static str {
        match self {
            Action::Lock => "lock",
            Action::Suspend => "suspend",
            Action::Logout => "logout",
            Action::Reboot => "reboot",
            Action::Shutdown => "shutdown",
        }
    }

    // locking loses nothing, so it doesn't ask; every other action does
    pub fn needs_confirm(self) -> bool {
        self != Action::Lock
    }

    pub fn run(self) {
        match self {
            // amane takes the session lock itself and does nothing while already locked
            Action::Lock => lock::start(),
            Action::Suspend => amane::spawn("systemctl suspend"),
            Action::Reboot => amane::spawn("systemctl reboot"),
            Action::Shutdown => amane::spawn("systemctl poweroff"),
            Action::Logout => compositor::logout(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_lock_runs_without_asking() {
        for action in ALL {
            assert_eq!(action.needs_confirm(), action != Action::Lock);
        }
    }

    #[test]
    fn every_action_has_its_own_label() {
        let mut labels: Vec<&str> = ALL.iter().map(|action| action.label()).collect();

        labels.sort_unstable();
        labels.dedup();

        assert_eq!(labels.len(), ALL.len());
    }
}
