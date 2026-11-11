use std::time::Duration;

use amane::{Center, Column, Media, Parent, Rectangle, Row, Service, Widget, children};

use super::{block, clickable, label, line, small};
use crate::hover;
use crate::spotify::{IDENTITY, Spotify};
use crate::text::shorten;
use crate::theme::{Theme, dash, size, space};

/*
 * what spotify is playing: the title and artist, a hairline for how far in
 * it is, and the time under its ends. spotify only, like the bar; a click
 * plays or pauses. reading Media redraws this every second while it plays,
 * which is only while the dashboard is drawn. the same pieces are drawn on
 * every tick, so a click is never lost to a line coming or going
 */
pub fn view(theme: &Theme, monitor: &str, width: f32) -> Option<Column> {
    let media = Media::read();

    let player = media
        .players()
        .iter()
        .find(|player| player.identity() == IDENTITY)?;

    let (title, artist, playing) = (
        player.title().to_string(),
        player.artist().to_string(),
        player.playing(),
    );

    let (position, length) = (player.position(), player.length());

    drop(media);

    let key = hover::key(monitor, "dash/playing");
    let hovered = hover::amount(&key);

    let row = line(
        "spotify",
        &title,
        &shorten(&artist, dash::TRAILING_CHARS),
        theme,
        hovered,
    );

    let track = clickable(row, key, |_| Spotify::play_pause());

    let fraction = if length.is_zero() {
        0.0
    } else {
        (position.as_secs_f32() / length.as_secs_f32()).clamp(0.0, 1.0)
    };

    let progress = Rectangle::new()
        .width(width)
        .height(dash::TRACK)
        .fill(theme.outline_variant)
        .child(
            Rectangle::new()
                .width(width * fraction)
                .height(dash::TRACK)
                .fill(theme.on_surface_variant),
        );

    let times = Row::new(children![
        Rectangle::new().width(dash::LEAD).height(size::SM * 1.5),
        small(clock(position), theme.on_surface_variant),
        Rectangle::new().width(Parent).height(size::SM * 1.5),
        small(clock(length), theme.on_surface_variant)
    ])
    .width(Parent)
    .gap(space::MD)
    .align(Center);

    let head = label(if playing { "playing" } else { "paused" }, theme);

    Some(block(
        Box::new(head),
        vec![
            Box::new(track) as Box<dyn Widget>,
            Box::new(Rectangle::new().width(Parent).height(space::XS)),
            Box::new(progress),
            Box::new(times),
        ],
    ))
}

// minutes and seconds, like "3:07"; an hour-long track keeps counting minutes
fn clock(time: Duration) -> String {
    let seconds = time.as_secs();

    format!("{}:{:02}", seconds / 60, seconds % 60)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn times_read_as_minutes_and_seconds() {
        assert_eq!(clock(Duration::ZERO), "0:00");
        assert_eq!(clock(Duration::from_secs(187)), "3:07");
        assert_eq!(clock(Duration::from_millis(3_725_900)), "62:05");
    }
}
