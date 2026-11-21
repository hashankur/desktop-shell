mod view;

use std::thread;
use std::time::{Duration, Instant};

use amane::{Battery, Service};

use crate::theme::{low_battery, timing};

pub use view::view;

// how often the charge is looked at; amane's own reading only changes every few seconds
const POLL: Duration = Duration::from_secs(2);

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Level {
    Low,
    Critical,
}

// what the warning says: how bad it is, and the charge when it came
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Alert {
    pub level: Level,
    pub percent: u8,
}

/*
 * warns when the battery runs low while unplugged, once at 15% and again at
 * 5%, and again after a charge and another unplug. it is its own window on
 * the overlay layer, not a notification, because a toast sits on the top
 * layer and a full-screen window hides it. a start or a reload while it is
 * already low warns once more, which is fine
 */
#[derive(Default)]
pub struct LowBattery {
    shown: Option<Alert>,

    // the one shown last, still drawn while it fades out
    last: Option<Alert>,
}

impl Service for LowBattery {
    fn new() -> Self {
        Self::default()
    }

    // the charge can't be waited on, so it is looked at every few seconds
    fn listen() {
        let mut warned: Option<Level> = None;
        let mut until: Option<Instant> = None;

        loop {
            thread::sleep(POLL);

            let battery = Battery::read();
            let (present, percent) = (battery.present(), battery.percent());
            let (charging, full) = (battery.charging(), battery.full());
            drop(battery);

            let now = present.then(|| level(percent, charging, full)).flatten();

            if let Some(level) = fire(warned, now) {
                until = Some(Instant::now() + Duration::from_secs_f32(timing::LOW_BATTERY));

                let alert = Some(Alert { level, percent });
                let mut state = Self::write();

                state.shown = alert;
                state.last = alert;
            } else if now.is_none() && Self::read().shown.is_some() {
                // plugged in, so there is nothing left to warn about
                until = None;

                Self::write().shown = None;
            } else if until.is_some_and(|until| Instant::now() >= until) {
                until = None;

                Self::write().shown = None;
            }

            warned = now;
        }
    }
}

impl LowBattery {
    pub fn shown(&self) -> Option<Alert> {
        self.shown
    }

    pub fn last(&self) -> Option<Alert> {
        self.last
    }
}

/*
 * how low it is, if it is a reason to warn: only while discharging. amane
 * reads 0 when the file won't parse, which is not a flat battery, so that
 * counts as unknown
 */
fn level(percent: u8, charging: bool, full: bool) -> Option<Level> {
    if charging || full || percent == 0 {
        return None;
    }

    match percent {
        percent if percent <= low_battery::CRITICAL => Some(Level::Critical),
        percent if percent <= low_battery::LOW => Some(Level::Low),
        _ => None,
    }
}

// warns when it is worse than what was last warned about; `None` is not low at all
fn fire(warned: Option<Level>, now: Option<Level>) -> Option<Level> {
    if now > warned { now } else { None }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn warns_only_while_discharging_and_low() {
        assert_eq!(level(40, false, false), None);
        assert_eq!(level(15, false, false), Some(Level::Low));
        assert_eq!(level(6, false, false), Some(Level::Low));
        assert_eq!(level(5, false, false), Some(Level::Critical));
        assert_eq!(level(3, true, false), None);
        assert_eq!(level(3, false, true), None);
    }

    #[test]
    fn an_unreadable_charge_is_not_a_flat_battery() {
        assert_eq!(level(0, false, false), None);
    }

    #[test]
    fn warns_once_per_level_and_again_once_it_got_worse() {
        assert_eq!(fire(None, Some(Level::Low)), Some(Level::Low));
        assert_eq!(fire(Some(Level::Low), Some(Level::Low)), None);
        assert_eq!(fire(Some(Level::Low), Some(Level::Critical)), Some(Level::Critical));
        assert_eq!(fire(Some(Level::Critical), Some(Level::Low)), None);

        // not low, or plugged in
        assert_eq!(fire(Some(Level::Low), None), None);
        assert_eq!(fire(None, None), None);
    }
}
