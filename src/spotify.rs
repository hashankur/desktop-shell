use std::thread;
use std::time::Duration;

use amane::{Media, Service};

// how the player names itself over mpris
const IDENTITY: &str = "Spotify";

/*
 * the bar's media is spotify only, by design: browser tabs and other mpris
 * players never show. amane's Media changes every second while anything
 * plays, since it carries the position, so this keeps only what the bar
 * shows and redraws when that changes
 */
#[derive(Default, Clone, PartialEq)]
pub struct Spotify {
    track: Option<Track>,
}

#[derive(Clone, PartialEq)]
pub struct Track {
    pub artist: String,
    pub title: String,
    pub playing: bool,
}

impl Service for Spotify {
    fn new() -> Self {
        read()
    }

    fn listen() {
        loop {
            thread::sleep(Duration::from_secs(1));

            let fresh = read();

            if *Self::read() != fresh {
                *Self::write() = fresh;
            }
        }
    }
}

impl Spotify {
    // none while spotify isn't open
    pub fn track(&self) -> Option<&Track> {
        self.track.as_ref()
    }

    pub fn play_pause() {
        if let Some(player) = Media::read()
            .players()
            .iter()
            .find(|player| player.identity() == IDENTITY)
        {
            player.play_pause();
        }
    }
}

fn read() -> Spotify {
    let media = Media::read();

    let track = media
        .players()
        .iter()
        .find(|player| player.identity() == IDENTITY)
        .map(|player| Track {
            artist: player.artist().to_string(),
            title: player.title().to_string(),
            playing: player.playing(),
        });

    Spotify { track }
}
