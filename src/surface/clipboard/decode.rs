use std::env;
use std::fs;
use std::io::Read;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::Mutex;
use std::thread;

use amane::Service;

use super::Clipboard;
use super::kind::Kind;
use super::parse::{Clip, is_id};
use super::text::{looks_like_code, tidy};
use crate::theme::clipboard;

// what the preview beside the list shows for one clip
#[derive(Clone, PartialEq)]
pub struct Preview {
    pub id: String,
    pub body: Body,
}

#[derive(Clone, PartialEq)]
pub enum Body {
    // the clip's text as far as it was read; `cut` when there was more
    Text {
        text: String,
        chars: usize,
        lines: usize,
        cut: bool,
        code: bool,
    },

    // the picture, whole on disk
    Image(PathBuf),

    // an image amane can't draw, or a clip that is gone
    Nothing,
}

// the clip whose preview was asked for last; an older one that lands late is dropped
static WANTED: Mutex<String> = Mutex::new(String::new());

/*
 * reads the clip off the ui thread and hands its preview to the surface.
 * the keys can move faster than cliphist answers, so only the clip asked
 * for last is kept
 */
pub fn want(clip: &Clip) {
    if Clipboard::read().preview.as_ref().is_some_and(|preview| preview.id == clip.id) {
        return;
    }

    {
        let mut wanted = WANTED.lock().unwrap_or_else(|poisoned| poisoned.into_inner());

        if *wanted == clip.id {
            return;
        }

        wanted.clone_from(&clip.id);
    }

    let clip = clip.clone();

    thread::spawn(move || {
        let body = body(&clip);

        let mut wanted = WANTED.lock().unwrap_or_else(|poisoned| poisoned.into_inner());

        if *wanted != clip.id {
            return;
        }

        // a later want of the same clip finds it in the service and stops there
        wanted.clear();

        let preview = Preview { id: clip.id, body };

        if Clipboard::read().preview.as_ref() != Some(&preview) {
            Clipboard::write().preview = Some(preview);
        }
    });
}

fn body(clip: &Clip) -> Body {
    match &clip.kind {
        Kind::Image { format, .. } => match extension(format) {
            Some(extension) => image(&clip.id, extension),
            None => Body::Nothing,
        },

        _ => text(&clip.id),
    }
}

// amane draws png and jpeg; anything else has no picture
fn extension(format: &str) -> Option<&'static str> {
    match format {
        "png" => Some("png"),
        "jpeg" | "jpg" => Some("jpg"),
        _ => None,
    }
}

/*
 * memory-backed and the user's own, like the screenshot's frames: copied
 * images can be anything, so they don't belong on disk
 */
pub fn folder() -> PathBuf {
    env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(env::temp_dir)
        .join("yohaku-clipboard")
}

/*
 * pictures of clips gone from the history go; the rest stay, since a clip
 * never changes under its id. deleting one a late read still points at would
 * leave amane remembering it as broken
 */
pub fn forget_except(clips: &[Clip]) {
    let Ok(files) = fs::read_dir(folder()) else {
        return;
    };

    for file in files.flatten() {
        let path = file.path();

        let kept = path
            .file_stem()
            .and_then(|stem| stem.to_str())
            .is_some_and(|id| clips.iter().any(|clip| clip.id == id));

        if !kept {
            let _ = fs::remove_file(path);
        }
    }
}

/*
 * written beside its place and renamed in: amane remembers a picture it
 * failed to decode, so it must never see half of one. a clip never changes
 * under its id, so one already there is used as is
 */
fn image(id: &str, extension: &str) -> Body {
    let path = folder().join(format!("{id}.{extension}"));

    if path.exists() {
        return Body::Image(path);
    }

    let Some((bytes, false)) = read(id, clipboard::IMAGE_BYTES) else {
        return Body::Nothing;
    };

    if bytes.is_empty() {
        return Body::Nothing;
    }

    let partial = path.with_extension("part");

    let written = fs::create_dir_all(folder())
        .and_then(|()| fs::write(&partial, &bytes))
        .and_then(|()| fs::rename(&partial, &path));

    match written {
        Ok(()) => Body::Image(path),
        Err(_) => Body::Nothing,
    }
}

fn text(id: &str) -> Body {
    let Some((bytes, cut)) = read(id, clipboard::TEXT_BYTES) else {
        return Body::Nothing;
    };

    let raw = String::from_utf8_lossy(&bytes);

    // a cut can land inside a letter
    let raw = raw.trim_end_matches('\u{FFFD}');

    let text = tidy(raw);

    Body::Text {
        chars: raw.chars().count(),
        lines: text.lines().count().max(1),
        code: looks_like_code(raw),
        text,
        cut,
    }
}

/*
 * the first `limit` bytes of the clip, and whether there was more. a clip
 * deleted since the list was read, or no cliphist, gives none. the id goes
 * in as an argument, never through a shell
 */
fn read(id: &str, limit: usize) -> Option<(Vec<u8>, bool)> {
    if !is_id(id) {
        return None;
    }

    let mut child = Command::new("cliphist")
        .args(["decode", id])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;

    let mut bytes = Vec::new();

    let read = child
        .stdout
        .take()
        .map(|stdout| stdout.take(limit as u64 + 1).read_to_end(&mut bytes));

    let whole = matches!(read, Some(Ok(_))) && bytes.len() <= limit;

    // past the limit cliphist may still be writing, so it is stopped rather than waited on
    if !whole {
        let _ = child.kill();
        let _ = child.wait();

        if !matches!(read, Some(Ok(_))) {
            return None;
        }

        bytes.truncate(limit);

        return Some((bytes, true));
    }

    child.wait().ok()?.success().then_some((bytes, false))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_drawable_images_get_a_file() {
        assert_eq!(extension("png"), Some("png"));
        assert_eq!(extension("jpeg"), Some("jpg"));
        assert_eq!(extension("webp"), None);
    }

    #[test]
    fn ids_never_reach_cliphist_unless_digits() {
        assert!(read("1; rm -rf ~", 10).is_none());
    }
}

