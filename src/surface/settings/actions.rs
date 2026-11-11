use std::process::{Command, Stdio};
use std::thread;

use amane::{Audio, Bluetooth, Brightness, Network, Service};

use super::Settings;
use super::rows::Action;
use crate::theme::settings::STEP;
use crate::toast::Quiet;
use crate::wallpaper;

// power-profiles-daemon's names, in the order enter steps through them
const PROFILES: [&str; 3] = ["power-saver", "balanced", "performance"];

// what enter does to a row
pub fn run(action: &Action) {
    match action {
        Action::Wifi => {
            let on = Network::read().wifi_enabled();
            Network::set_wifi(!on);
        }

        Action::Bluetooth => {
            let on = Bluetooth::read().powered();
            Bluetooth::set_powered(!on);
        }

        Action::Quiet => Quiet::toggle(),

        Action::Profile => {
            let current = Settings::read().profile.clone();
            set_profile(next_profile(current.as_deref()));
        }

        Action::Volume => Audio::toggle_mute(),

        Action::Brightness => {}

        Action::Network { ssid, active, joinable } => {
            if *active {
                Network::disconnect();
            } else if *joinable {
                Network::connect(ssid, None);
            }
        }

        Action::Device { path, connected, paired } => {
            if *connected {
                Bluetooth::disconnect(path);
            } else if *paired {
                Bluetooth::connect(path);
            } else {
                Bluetooth::pair(path);
            }
        }

        Action::Scan => {
            if Bluetooth::read().scanning() {
                Bluetooth::stop_scan();
            } else {
                Bluetooth::start_scan();
            }
        }

        Action::Wallpaper(path) => {
            wallpaper::set(path);
        }

        Action::Nothing => {}
    }
}

// a level row up or down a step; other rows don't have a level
pub fn adjust(action: &Action, up: bool) {
    let step = |level: u8| {
        if up {
            level.saturating_add(STEP).min(100)
        } else {
            level.saturating_sub(STEP)
        }
    };

    match action {
        Action::Volume => {
            let volume = Audio::read().volume();
            Audio::set_volume(step(volume));
        }

        Action::Brightness => {
            let brightness = Brightness::read().percent();
            Brightness::set(step(brightness));
        }

        _ => {}
    }
}

fn next_profile(current: Option<&str>) -> &'static str {
    let index = current
        .and_then(|current| PROFILES.iter().position(|profile| *profile == current))
        .map_or(1, |index| (index + 1) % PROFILES.len());

    PROFILES[index]
}

// asks the daemon which profile is on, off the ui thread; none when it isn't running
pub fn read_profile() {
    thread::spawn(|| {
        let profile = Command::new("powerprofilesctl")
            .arg("get")
            .stderr(Stdio::null())
            .output()
            .ok()
            .filter(|output| output.status.success())
            .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
            .filter(|profile| !profile.is_empty());

        if Settings::read().profile != profile {
            Settings::write().profile = profile;
        }
    });
}

fn set_profile(profile: &'static str) {
    thread::spawn(move || {
        let _ = Command::new("powerprofilesctl")
            .args(["set", profile])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();

        read_profile();
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn steps_through_the_profiles() {
        assert_eq!(next_profile(Some("power-saver")), "balanced");
        assert_eq!(next_profile(Some("balanced")), "performance");
        assert_eq!(next_profile(Some("performance")), "power-saver");
        assert_eq!(next_profile(None), "balanced");
    }
}
