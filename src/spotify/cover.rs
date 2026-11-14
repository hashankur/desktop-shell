use std::fs;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::path::PathBuf;
use std::process::Command;
use std::thread;

use amane::Service;

use super::{Spotify, Track};
use crate::theme;

// how long a cover download may take before the track goes without one
const DOWNLOAD_SECONDS: &str = "15";

// the album and the picture for one track, looked up once when it starts
#[derive(Clone, PartialEq)]
pub struct Cover {
    // the track it belongs to, so a new track never shows the last one's
    pub(super) title: String,
    pub(super) artist: String,

    // empty when the player doesn't say
    pub album: String,

    // only set once the file is whole on disk: amane remembers a picture it failed to decode
    pub art: Option<PathBuf>,
}

/*
 * asks the player for the album and fetches the picture, off the ui thread,
 * then hands both to the service if the track is still the one playing.
 * spotify gives an https link; every album's picture is kept in yohaku's
 * cache, so a track heard before shows its cover at once
 */
pub fn look_up(track: Track) {
    thread::spawn(move || {
        let album = album();
        let art = picture(&track.art_url);

        let cover = Cover {
            title: track.title,
            artist: track.artist,
            album,
            art,
        };

        let spotify = Spotify::read();

        let current = spotify
            .track
            .as_ref()
            .is_some_and(|playing| playing.title == cover.title && playing.artist == cover.artist);

        if !current || spotify.cover.as_ref() == Some(&cover) {
            return;
        }

        drop(spotify);

        Spotify::write().cover = Some(cover);
    });
}

// mpris has the album, amane's player doesn't carry it
fn album() -> String {
    Command::new("playerctl")
        .args(["--player=spotify", "metadata", "xesam:album"])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .unwrap_or_default()
}

fn picture(url: &str) -> Option<PathBuf> {
    if let Some(path) = url.strip_prefix("file://") {
        return Some(PathBuf::from(path));
    }

    if !url.starts_with("https://") && !url.starts_with("http://") {
        return None;
    }

    let folder = theme::cache_folder().join("art");
    let path = folder.join(name(url));

    if path.exists() {
        return Some(path);
    }

    fs::create_dir_all(&folder).ok()?;

    // downloaded aside and moved in, so a decode never sees half a file
    let partial = path.with_extension("part");

    let fetched = Command::new("curl")
        .args(["--fail", "--silent", "--location", "--max-time", DOWNLOAD_SECONDS, "--output"])
        .arg(&partial)
        .arg(url)
        .status()
        .is_ok_and(|status| status.success());

    if !fetched || fs::rename(&partial, &path).is_err() {
        let _ = fs::remove_file(&partial);

        return None;
    }

    Some(path)
}

// the link's hash names the file; amane reads the format from the bytes, not the name
fn name(url: &str) -> String {
    let mut hasher = DefaultHasher::new();

    url.hash(&mut hasher);

    format!("{:016x}", hasher.finish())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_a_cover_by_its_link() {
        let link = "https://i.scdn.co/image/ab67616d0000b273e87ff33b18fb6fe39f9a7530";

        assert_eq!(name(link), name(link));
        assert_ne!(name(link), name("https://i.scdn.co/image/other"));
        assert_eq!(name(link).len(), 16);
    }

    #[test]
    fn a_local_cover_is_used_where_it_is() {
        assert_eq!(picture("file:///tmp/cover.png"), Some(PathBuf::from("/tmp/cover.png")));
        assert_eq!(picture(""), None);
        assert_eq!(picture("data:image/png;base64,AAAA"), None);
    }
}
