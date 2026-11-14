use std::path::PathBuf;
use std::time::Duration;

use amane::{
    Center, Column, Image, Media, Parent, Rectangle, Row, Service, Text, Widget, children,
};

use super::parts::{button, label, line, small, spacer};
use crate::hover;
use crate::spotify::{IDENTITY, Spotify};
use crate::theme::{SANS, Theme, dash, space};

/*
 * what spotify is playing, around its cover: the picture, the title, artist
 * and album under it, then a line for how far in it is with the times
 * under its ends. spotify only, like the bar; a click on the cover
 * plays or pauses. reading Media redraws this every second while it plays,
 * which is only while the dashboard is drawn
 */
pub fn view(theme: &Theme, monitor: &str, width: f32) -> Option<Column> {
    let spotify = Spotify::read();
    let track = spotify.track()?.clone();
    let cover = spotify.cover().cloned();
    drop(spotify);

    let media = Media::read();

    let (position, length) = media
        .players()
        .iter()
        .find(|player| player.identity() == IDENTITY)
        .map(|player| (player.position(), player.length()))
        .unwrap_or_default();

    drop(media);

    let art = cover.as_ref().and_then(|cover| cover.art.clone());
    let album = cover.map(|cover| cover.album).unwrap_or_default();

    let art = button(picture(art, width, theme), hover::key(monitor, "dash/cover"), |_| {
        Spotify::play_pause()
    });

    let state = if track.playing { "playing" } else { "paused" };

    let mut items: Vec<Box<dyn Widget>> = vec![
        Box::new(art),
        Box::new(spacer(space::LG)),
        Box::new(label(&format!("{state} · spotify"), theme)),
        Box::new(
            Text::new(track.title)
                .font(SANS)
                .size(dash::TITLE)
                .weight(dash::TITLE_WEIGHT)
                .color(theme.on_surface)
                .elide(),
        ),
        Box::new(
            Text::new(track.artist)
                .font(SANS)
                .size(dash::HEADING)
                .color(theme.on_surface_variant)
                .elide(),
        ),
    ];

    // the album sits a step apart from the artist, so the two names don't read as one
    if !album.is_empty() {
        items.push(Box::new(spacer(space::SM)));
        items.push(Box::new(small(album, theme.outline).elide()));
    }

    items.extend([
        Box::new(spacer(space::MD)) as Box<dyn Widget>,
        Box::new(progress(position, length, width, theme)),
        Box::new(spacer(space::SM)),
        Box::new(times(position, length, width, theme)),
    ]);

    Some(Column::new(items).width(width))
}

// the cover, square; a plain square until it has been fetched, so nothing moves when it arrives
fn picture(art: Option<PathBuf>, size: f32, theme: &Theme) -> Rectangle {
    let square = Rectangle::new()
        .width(size)
        .height(size)
        .radius(dash::ART_RADIUS);

    match art {
        Some(path) => square.fill(Image::cover(path)),
        None => square.fill(theme.outline_variant),
    }
}

fn progress(position: Duration, length: Duration, width: f32, theme: &Theme) -> Rectangle {
    let fraction = if length.is_zero() {
        0.0
    } else {
        (position.as_secs_f32() / length.as_secs_f32()).clamp(0.0, 1.0)
    };

    Rectangle::new()
        .width(width)
        .height(dash::PROGRESS)
        .radius(dash::PROGRESS / 2.0)
        .fill(theme.outline_variant)
        .child(
            Rectangle::new()
                .width(width * fraction)
                .height(dash::PROGRESS)
                .radius(dash::PROGRESS / 2.0)
                .fill(theme.on_surface),
        )
}

fn times(position: Duration, length: Duration, width: f32, theme: &Theme) -> Row {
    Row::new(children![
        small(clock(position), theme.on_surface_variant),
        Rectangle::new().width(Parent).height(line(dash::SMALL)),
        small(clock(length), theme.on_surface_variant)
    ])
    .width(width)
    .align(Center)
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
