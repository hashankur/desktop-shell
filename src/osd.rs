mod view;

use std::fs;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, Instant};

use amane::{Audio, Service};

use crate::theme::timing;

pub use view::view;

// how often the levels are looked at; quick enough that a key press feels answered
const POLL: Duration = Duration::from_millis(50);

const BACKLIGHTS: &str = "/sys/class/backlight";

// what the osd says: the one level that just changed
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Reading {
    Volume { percent: u8, muted: bool },
    Microphone { muted: bool },
    Brightness { percent: u8 },
}

// the levels the keys change, as last seen
#[derive(Debug, Clone, Copy, PartialEq)]
struct Levels {
    volume: u8,
    muted: bool,
    microphone_muted: bool,

    // none without a backlight, like on a desktop monitor
    brightness: Option<u8>,
}

/*
 * shows whatever level just changed, from any source: the keys run wpctl
 * and brightnessctl straight from the compositor, so the osd watches the
 * levels instead of being told. the first look is only remembered, so a
 * start or a reload never shows it
 */
#[derive(Default)]
pub struct Osd {
    shown: Option<Reading>,

    // the one shown last, still drawn while it fades out
    last: Option<Reading>,
}

impl Service for Osd {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        let backlight = find_backlight();

        let mut seen = levels(backlight.as_deref());
        let mut until: Option<Instant> = None;

        /*
         * with the sound server not up yet, like at login, amane reads the
         * volume as 0 until it connects; that first real value is not a key
         * press, so changes are only remembered at first
         */
        let settled = Instant::now() + Duration::from_secs_f32(timing::OSD_SETTLE);

        loop {
            thread::sleep(POLL);

            let now = levels(backlight.as_deref());

            if Instant::now() < settled {
                seen = now;
                continue;
            }

            if let Some(reading) = changed(&seen, &now) {
                until = Some(Instant::now() + Duration::from_secs_f32(timing::OSD));

                let mut osd = Self::write();

                osd.shown = Some(reading);
                osd.last = Some(reading);
            } else if until.is_some_and(|until| Instant::now() >= until) {
                until = None;

                Self::write().shown = None;
            }

            seen = now;
        }
    }
}

impl Osd {
    pub fn shown(&self) -> Option<Reading> {
        self.shown
    }

    pub fn last(&self) -> Option<Reading> {
        self.last
    }
}

/*
 * which level changed between two looks; volume first, since its keys are
 * pressed most. brightness only counts when both looks found the backlight
 */
fn changed(before: &Levels, after: &Levels) -> Option<Reading> {
    if (before.volume, before.muted) != (after.volume, after.muted) {
        return Some(Reading::Volume {
            percent: after.volume,
            muted: after.muted,
        });
    }

    if before.microphone_muted != after.microphone_muted {
        return Some(Reading::Microphone {
            muted: after.microphone_muted,
        });
    }

    match (before.brightness, after.brightness) {
        (Some(old), Some(new)) if old != new => Some(Reading::Brightness { percent: new }),
        _ => None,
    }
}

fn levels(backlight: Option<&Path>) -> Levels {
    let audio = Audio::read();

    Levels {
        volume: audio.volume(),
        muted: audio.muted(),
        microphone_muted: audio.microphone_muted(),
        brightness: backlight.and_then(brightness),
    }
}

// the first backlight there is; amane's Brightness only looks twice a second, too slow for keys
fn find_backlight() -> Option<PathBuf> {
    fs::read_dir(BACKLIGHTS)
        .ok()?
        .flatten()
        .map(|entry| entry.path())
        .next()
}

fn brightness(backlight: &Path) -> Option<u8> {
    let read = |name: &str| -> Option<u64> {
        fs::read_to_string(backlight.join(name))
            .ok()?
            .trim()
            .parse()
            .ok()
    };

    let (current, highest) = (read("brightness")?, read("max_brightness")?);

    (highest > 0).then(|| ((current * 100 + highest / 2) / highest).min(100) as u8)
}

#[cfg(test)]
mod tests {
    use super::*;

    const RESTING: Levels = Levels {
        volume: 40,
        muted: false,
        microphone_muted: false,
        brightness: Some(70),
    };

    #[test]
    fn nothing_changed_shows_nothing() {
        assert_eq!(changed(&RESTING, &RESTING), None);
    }

    #[test]
    fn says_which_level_changed() {
        let louder = Levels {
            volume: 45,
            ..RESTING
        };
        let muted = Levels {
            muted: true,
            ..RESTING
        };
        let microphone = Levels {
            microphone_muted: true,
            ..RESTING
        };
        let dimmer = Levels {
            brightness: Some(50),
            ..RESTING
        };

        assert_eq!(
            changed(&RESTING, &louder),
            Some(Reading::Volume {
                percent: 45,
                muted: false
            })
        );
        assert_eq!(
            changed(&RESTING, &muted),
            Some(Reading::Volume {
                percent: 40,
                muted: true
            })
        );
        assert_eq!(
            changed(&RESTING, &microphone),
            Some(Reading::Microphone { muted: true })
        );
        assert_eq!(
            changed(&RESTING, &dimmer),
            Some(Reading::Brightness { percent: 50 })
        );
    }

    #[test]
    fn a_backlight_coming_or_going_is_not_a_change() {
        let gone = Levels {
            brightness: None,
            ..RESTING
        };

        assert_eq!(changed(&RESTING, &gone), None);
        assert_eq!(changed(&gone, &RESTING), None);
    }
}
