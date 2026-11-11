use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

use amane::Service;

const POWER_SUPPLY: &str = "/sys/class/power_supply";

/*
 * how long the battery has left, or how long until it's full, which amane's
 * Battery doesn't say. worked out from sysfs energy and power the way upower
 * does; nothing while the rate reads zero (just plugged in, or full)
 */
#[derive(Default)]
pub struct Charge {
    path: Option<PathBuf>,
    remaining: Option<Remaining>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Remaining {
    pub minutes: u32,
    pub charging: bool,
}

impl Service for Charge {
    fn new() -> Self {
        let mut charge = Self {
            path: find(),
            remaining: None,
        };

        charge.update();

        charge
    }

    // the rate moves with load, so a slow read keeps the estimate from jittering
    fn interval() -> Duration {
        Duration::from_secs(30)
    }

    fn update(&mut self) -> bool {
        let remaining = self.path.as_deref().and_then(remaining);

        if remaining == self.remaining {
            return false;
        }

        self.remaining = remaining;

        true
    }
}

impl Charge {
    pub fn remaining(&self) -> Option<Remaining> {
        self.remaining
    }
}

// "2h 47m", or "40m" under an hour
pub fn duration(minutes: u32) -> String {
    match (minutes / 60, minutes % 60) {
        (0, minutes) => format!("{minutes}m"),
        (hours, minutes) => format!("{hours}h {minutes}m"),
    }
}

// the system's own battery, not a mouse or headset reporting one
fn find() -> Option<PathBuf> {
    let read = |path: &Path, name: &str| fs::read_to_string(path.join(name)).unwrap_or_default();

    fs::read_dir(POWER_SUPPLY)
        .ok()?
        .flatten()
        .map(|entry| entry.path())
        .find(|path| read(path, "type").trim() == "Battery" && read(path, "scope").trim() != "Device")
}

fn remaining(battery: &Path) -> Option<Remaining> {
    let read = |name: &str| fs::read_to_string(battery.join(name)).ok()?.trim().parse::<f64>().ok();

    // some batteries report charge and current instead of energy and power; the hours come out the same
    let (now, full, rate) = match (read("energy_now"), read("energy_full"), read("power_now")) {
        (Some(now), Some(full), Some(rate)) => (now, full, rate),
        _ => (read("charge_now")?, read("charge_full")?, read("current_now")?),
    };

    let status = fs::read_to_string(battery.join("status")).ok()?;

    hours(status.trim(), now, full, rate).map(|(hours, charging)| Remaining {
        minutes: (hours * 60.0).round() as u32,
        charging,
    })
}

fn hours(status: &str, now: f64, full: f64, rate: f64) -> Option<(f64, bool)> {
    // some drivers report the rate negative while discharging
    let rate = rate.abs();

    if rate <= 0.0 {
        return None;
    }

    match status {
        "Discharging" => Some((now / rate, false)),
        "Charging" => Some(((full - now).max(0.0) / rate, true)),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn duration_drops_hours_under_one() {
        assert_eq!(duration(40), "40m");
        assert_eq!(duration(167), "2h 47m");
        assert_eq!(duration(60), "1h 0m");
    }

    #[test]
    fn hours_follow_the_status() {
        assert_eq!(hours("Discharging", 30.0, 40.0, 10.0), Some((3.0, false)));
        assert_eq!(hours("Charging", 30.0, 40.0, -10.0), Some((1.0, true)));
        assert_eq!(hours("Full", 40.0, 40.0, 10.0), None);
        assert_eq!(hours("Discharging", 30.0, 40.0, 0.0), None);
    }
}
