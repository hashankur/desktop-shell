mod cover;

use std::thread;
use std::time::Duration;

use amane::{Media, MediaPlayer, Service};

pub use cover::Cover;

// how the player names itself over mpris
pub const IDENTITY: &str = "Spotify";

/*
 * the bar's media is spotify only, by design: browser tabs and other mpris
 * players never show. amane's Media changes every second while anything
 * plays, since it carries the position, so this keeps only what the bar
 * shows and redraws when that changes
 */
#[derive(Default, Clone, PartialEq)]
pub struct Spotify {
    track: Option<Track>,

    // the album and picture of the track, once looked up
    cover: Option<Cover>,
}

#[derive(Clone, PartialEq)]
pub struct Track {
    pub artist: String,
    pub title: String,
    pub playing: bool,
    pub art_url: String,
}

impl Service for Spotify {
    fn new() -> Self {
        Spotify {
            track: read(),
            cover: None,
        }
    }

    fn listen() {
        // the track already playing when the shell starts gets its cover too
        if let Some(track) = Self::read().track.clone() {
            cover::look_up(track);
        }

        loop {
            thread::sleep(Duration::from_secs(1));

            let fresh = read();
            let current = Self::read().track.clone();

            if current == fresh {
                continue;
            }

            // pausing changes the track's state, not its cover
            let same_song = match (&current, &fresh) {
                (Some(current), Some(fresh)) => {
                    current.title == fresh.title
                        && current.artist == fresh.artist
                        && current.art_url == fresh.art_url
                }
                _ => false,
            };

            Self::write().track = fresh.clone();

            if let Some(track) = fresh.filter(|_| !same_song) {
                cover::look_up(track);
            }
        }
    }
}

impl Spotify {
    // none while spotify isn't open
    pub fn track(&self) -> Option<&Track> {
        self.track.as_ref()
    }

    // the playing track's album and picture, none until they have been looked up
    pub fn cover(&self) -> Option<&Cover> {
        let track = self.track.as_ref()?;

        self.cover
            .as_ref()
            .filter(|cover| cover.title == track.title && cover.artist == track.artist)
    }

    pub fn play_pause() {
        with_player(MediaPlayer::play_pause);
    }
}

fn with_player(action: impl FnOnce(&MediaPlayer)) {
    if let Some(player) = Media::read()
        .players()
        .iter()
        .find(|player| player.identity() == IDENTITY)
    {
        action(player);
    }
}

fn read() -> Option<Track> {
    let media = Media::read();

    media
        .players()
        .iter()
        .find(|player| player.identity() == IDENTITY)
        .map(|player| Track {
            artist: player.artist().to_string(),
            title: player.title().to_string(),
            playing: player.playing(),
            art_url: player.art_url().to_string(),
        })
}
