use amane::{Audio, Center, Link, Network, Row, Service, Text, Widget};

use super::parts::{clickable, hovered_color, icon, tag};
use crate::hover;
use crate::icons;
use crate::theme::{MONO, Theme, bar};

// how far one scroll step moves the volume, in percent
const VOLUME_STEP: u8 = 5;

// NET, the connection's icon, then the volume, which a click mutes and scrolling moves
pub fn view(theme: &Theme, monitor: &str) -> Row {
    let mut items: Vec<Box<dyn Widget>> = vec![Box::new(tag("NET", theme))];

    if let Some(path) = icons::symbolic(network_icon(), theme.on_surface_variant) {
        items.push(Box::new(icon(path)));
    }

    items.push(Box::new(volume(theme, monitor)));

    // a tag and its items sit a group gap apart; only an icon and its own text are close
    Row::new(items).gap(bar::GROUP_GAP).align(Center)
}

fn volume(theme: &Theme, monitor: &str) -> amane::Rectangle {
    let audio = Audio::read();
    let (volume, muted) = (audio.volume(), audio.muted());
    drop(audio);

    let key = hover::key(monitor, "volume");
    let color = hovered_color(&key, theme);

    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(path) = icons::symbolic(volume_icon(volume, muted), color) {
        items.push(Box::new(icon(path)));
    }

    items.push(Box::new(
        Text::new(volume.to_string())
            .font(MONO)
            .size(bar::TEXT)
            .color(color),
    ));

    clickable(
        Row::new(items).gap(bar::ITEM_GAP).align(Center),
        key,
        |_| Audio::toggle_mute(),
    )
    .on_scroll(|scroll| {
        let volume = Audio::read().volume();

        // scrolling up raises it
        let next = if scroll.y < 0.0 {
            volume.saturating_add(VOLUME_STEP)
        } else {
            volume.saturating_sub(VOLUME_STEP)
        };

        Audio::set_volume(next);
    })
}

// neue's thresholds
fn network_icon() -> &'static str {
    let network = Network::read();

    match network.link() {
        Link::Wired => "network-wired",
        Link::Other => "network-vpn",
        Link::Wifi => match network.strength() {
            91.. => "network-wireless-signal-excellent",
            71..=90 => "network-wireless-signal-good",
            41..=70 => "network-wireless-signal-ok",
            1..=40 => "network-wireless-signal-weak",
            0 => "network-wireless-signal-none",
        },
        Link::Offline if network.connecting() => "network-wireless-acquiring",
        Link::Offline if !network.wifi_enabled() => "network-wireless-disabled",
        Link::Offline => "network-wireless-offline",
    }
}

fn volume_icon(volume: u8, muted: bool) -> &'static str {
    match (muted, volume) {
        (true, _) | (_, 0) => "audio-volume-muted",
        (_, 1..=33) => "audio-volume-low",
        (_, 34..=66) => "audio-volume-medium",
        _ => "audio-volume-high",
    }
}
