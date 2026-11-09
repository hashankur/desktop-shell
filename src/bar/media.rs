use amane::{Center, Rectangle, Row, Service, Text, Widget};

use super::parts::{clickable, hovered_color, icon, shorten};
use crate::hover;
use crate::icons;
use crate::spotify::Spotify;
use crate::theme::{SANS, Theme, bar};

// spotify's track, none while it isn't open; the icon is the action a click takes, as in neue
pub fn view(theme: &Theme, monitor: &str) -> Option<Rectangle> {
    let spotify = Spotify::read();
    let track = spotify.track()?.clone();
    drop(spotify);

    let key = hover::key(monitor, "media");
    let color = hovered_color(&key, theme);

    let action = if track.playing {
        "media-playback-pause"
    } else {
        "media-playback-start"
    };

    let label = match (track.artist.is_empty(), track.title.is_empty()) {
        (false, false) => format!("{} - {}", track.artist, track.title),
        (true, false) => track.title,
        (false, true) => track.artist,
        (true, true) => String::from("Spotify"),
    };

    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(path) = icons::symbolic(action, color) {
        items.push(Box::new(icon(path)));
    }

    items.push(Box::new(
        Text::new(shorten(&label, bar::MEDIA_CHARS))
            .font(SANS)
            .size(bar::TEXT)
            .color(color),
    ));

    Some(clickable(
        Row::new(items).gap(bar::ITEM_GAP).align(Center),
        key,
        |_| Spotify::play_pause(),
    ))
}
