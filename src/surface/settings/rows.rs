use std::path::{Path, PathBuf};

use amane::{Audio, Bluetooth, Brightness, Network, Service};

use super::{Page, Settings};
use crate::toast::Quiet;
use crate::wallpaper::Wallpaper;

// one line of a page: what it is, its state, and what enter does to it
pub struct Row {
    pub name: String,
    pub value: String,
    pub action: Action,
}

#[derive(Clone, PartialEq)]
pub enum Action {
    Wifi,
    Bluetooth,
    Quiet,
    Profile,
    // enter mutes; minus, plus and the wheel change the level
    Volume,
    Brightness,
    // join, or leave the one joined; a locked network not joined before can't be joined from here yet
    Network { ssid: String, active: bool, joinable: bool },
    Device { path: String, connected: bool, paired: bool },
    Scan,
    Wallpaper(PathBuf),
    // a line that only says something
    Nothing,
}

fn row(name: impl Into<String>, value: impl Into<String>, action: Action) -> Row {
    Row {
        name: name.into(),
        value: value.into(),
        action,
    }
}

fn on_off(on: bool) -> &'static str {
    if on { "on" } else { "off" }
}

pub fn rows(page: Page) -> Vec<Row> {
    match page {
        Page::Quick => quick(),
        Page::Network => network(),
        Page::Bluetooth => bluetooth(),
        Page::Appearance => appearance(),
    }
}

// the switches and levels worth one keypress; each leaves when this machine doesn't have it
fn quick() -> Vec<Row> {
    let mut rows = Vec::new();

    rows.push(row("wi-fi", on_off(Network::read().wifi_enabled()), Action::Wifi));

    let bluetooth = Bluetooth::read();
    if bluetooth.available() {
        rows.push(row("bluetooth", on_off(bluetooth.powered()), Action::Bluetooth));
    }
    drop(bluetooth);

    rows.push(row("do not disturb", on_off(Quiet::read().on()), Action::Quiet));

    if let Some(profile) = Settings::read().profile.clone() {
        rows.push(row("power profile", profile.replace('-', " "), Action::Profile));
    }

    let audio = Audio::read();
    let volume = if audio.muted() {
        String::from("muted")
    } else {
        audio.volume().to_string()
    };
    drop(audio);

    rows.push(row("volume", volume, Action::Volume));

    let brightness = Brightness::read();
    if brightness.present() {
        rows.push(row("brightness", brightness.percent().to_string(), Action::Brightness));
    }

    rows
}

/*
 * the networks in range, the joined one first, then by strength. a name
 * seen from several access points is listed once
 */
fn network() -> Vec<Row> {
    let network = Network::read();

    if !network.wifi_enabled() {
        return vec![row("wi-fi is off", "turn on", Action::Wifi)];
    }

    let mut points: Vec<_> = network
        .access_points()
        .iter()
        .filter(|point| !point.ssid().is_empty())
        .collect();

    points.sort_by(|a, b| b.active().cmp(&a.active()).then(b.strength().cmp(&a.strength())));

    let mut rows: Vec<Row> = Vec::new();

    for point in points {
        if rows.iter().any(|row| row.name == point.ssid()) {
            continue;
        }

        let joinable = point.saved() || !point.secured();

        let value = if point.active() {
            String::from("connected")
        } else if !joinable {
            format!("{} locked", point.strength())
        } else {
            point.strength().to_string()
        };

        rows.push(row(
            point.ssid(),
            value,
            Action::Network {
                ssid: point.ssid().to_string(),
                active: point.active(),
                joinable,
            },
        ));
    }

    if rows.is_empty() {
        rows.push(row(if network.connecting() { "joining" } else { "looking for networks" }, "", Action::Nothing));
    }

    rows
}

// known devices, then whatever a scan finds, then the scan itself
fn bluetooth() -> Vec<Row> {
    let bluetooth = Bluetooth::read();

    if !bluetooth.available() {
        return vec![row("no bluetooth adapter", "", Action::Nothing)];
    }

    if !bluetooth.powered() {
        return vec![row("bluetooth is off", "turn on", Action::Bluetooth)];
    }

    let mut devices: Vec<_> = bluetooth.devices().iter().filter(|device| !device.name().is_empty()).collect();

    devices.sort_by(|a, b| {
        b.connected()
            .cmp(&a.connected())
            .then(b.paired().cmp(&a.paired()))
            .then(a.name().cmp(b.name()))
    });

    let mut rows: Vec<Row> = devices
        .into_iter()
        .map(|device| {
            let value = match (device.connected(), device.battery()) {
                (true, Some(battery)) => format!("connected {battery}%"),
                (true, None) => String::from("connected"),
                (false, _) if device.paired() => String::from("paired"),
                _ => String::new(),
            };

            row(
                device.name(),
                value,
                Action::Device {
                    path: device.path().to_string(),
                    connected: device.connected(),
                    paired: device.paired(),
                },
            )
        })
        .collect();

    let scan = if bluetooth.scanning() { "stop scanning" } else { "scan for devices" };

    rows.push(row(scan, "", Action::Scan));

    rows
}

// the wallpapers folder by full name, each with its size once known and the one in use marked; choosing one recolors the shell after it
fn appearance() -> Vec<Row> {
    let current = Wallpaper::read().path().map(Path::to_path_buf);

    let settings = Settings::read();

    if settings.wallpapers.is_empty() {
        return vec![row("no wallpapers", "~/Pictures/Wallpapers", Action::Nothing)];
    }

    settings
        .wallpapers
        .iter()
        .map(|path| {
            let name = path
                .file_stem()
                .map(|stem| stem.to_string_lossy().into_owned())
                .unwrap_or_default();

            let resolution = settings.pictures.get(path).and_then(|picture| picture.resolution());

            let value = match (current.as_deref() == Some(path.as_path()), resolution) {
                (true, Some(resolution)) => format!("current · {resolution}"),
                (true, None) => String::from("current"),
                (false, resolution) => resolution.unwrap_or_default(),
            };

            row(name, value, Action::Wallpaper(path.clone()))
        })
        .collect()
}
