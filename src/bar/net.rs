use amane::{Center, End, Link, Network, Rectangle, Row, Service, Text, Widget};

use super::parts::{hoverable, icon, reading, reveal};
use crate::hover;
use crate::icons;
use crate::theme::{SANS, Theme, bar};

/*
 * the connection's icon alone; under the pointer it unfolds the network's
 * name and signal, as neue's tooltip did. the volume lives in the osd and
 * settings, not here
 */
pub fn view(theme: &Theme, monitor: &str) -> Rectangle {
    let key = hover::key(monitor, "network");
    let amount = hover::amount(&key);

    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(path) = icons::symbolic(network_icon(), theme.on_surface_variant) {
        items.push(Box::new(icon(path)));
    }

    if let Some(detail) = reveal(network_detail(theme), bar::ITEM_GAP, amount) {
        items.push(Box::new(detail));
    }

    hoverable(Row::new(items).align(Center), key)
}

// "Home-5G 82% signal" on wifi, otherwise a word for the state
fn network_detail(theme: &Theme) -> Row {
    let network = Network::read();

    let word = |word: &str| {
        Text::new(word)
            .font(SANS)
            .size(bar::TEXT)
            .weight(bar::TEXT_WEIGHT)
            .color(theme.on_surface_variant)
    };

    let items: Vec<Box<dyn Widget>> = match network.link() {
        Link::Wifi => vec![
            Box::new(word(network.ssid())),
            Box::new(reading(format!("{}%", network.strength()), "signal", theme)),
        ],
        Link::Wired => vec![Box::new(word("wired"))],
        Link::Other => vec![Box::new(word("connected"))],
        Link::Offline if network.connecting() => vec![Box::new(word("connecting"))],
        Link::Offline if !network.wifi_enabled() => vec![Box::new(word("wifi off"))],
        Link::Offline => vec![Box::new(word("offline"))],
    };

    Row::new(items).gap(bar::ITEM_GAP).align(End)
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
