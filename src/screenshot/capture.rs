use std::env;
use std::fs::{self, File};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

use super::region::{self, PNG_HEADER};

/*
 * the external tools behind a screenshot: grim takes the frames, magick
 * cuts the box out of a frozen one, wl-copy puts the result on the
 * clipboard. everything here waits on a program, so it runs on its own
 * thread, never in a view
 */

// one output's still frame, taken when a region capture starts
pub struct Frozen {
    pub output: String,
    pub path: PathBuf,

    // in the picture's own pixels, more than the window's units on a scaled output
    pub size: (u32, u32),
}

/*
 * a frame of every output, all taken at once so they show the same moment;
 * none unless every one worked, so the overlay never comes up half frozen
 */
pub fn freeze(outputs: &[String]) -> Option<Vec<Frozen>> {
    let folder = frozen_folder();

    if let Err(error) = fs::create_dir_all(&folder) {
        eprintln!("yohaku: no folder for screenshot frames: {error}");
        return None;
    }

    // a fresh name every time: amane keeps decoded pictures by path, and would show the last shot
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|time| time.as_nanos())
        .unwrap_or_default();

    let started: Vec<(String, PathBuf, Option<std::process::Child>)> = outputs
        .iter()
        .map(|output| {
            let path = folder.join(format!("{stamp}-{output}.png"));

            // no compression, the frame is read back at once and thrown away
            let child = Command::new("grim")
                .args(["-l", "0", "-o", output])
                .arg(&path)
                .stdin(Stdio::null())
                .spawn()
                .map_err(|error| eprintln!("yohaku: failed to start grim: {error}"))
                .ok();

            (output.clone(), path, child)
        })
        .collect();

    let mut frozen = Vec::new();
    let mut failed = false;

    for (output, path, child) in started {
        let finished =
            child.is_some_and(|mut child| child.wait().is_ok_and(|status| status.success()));

        match finished.then(|| picture_size(&path)).flatten() {
            Some(size) => frozen.push(Frozen { output, path, size }),

            None => {
                eprintln!("yohaku: grim could not capture {output}");
                failed = true;
                let _ = fs::remove_file(&path);
            }
        }
    }

    if failed || frozen.is_empty() {
        discard(&frozen);
        return None;
    }

    Some(frozen)
}

// the frames are only needed while a region is chosen
pub fn discard(frozen: &[Frozen]) {
    for frame in frozen {
        let _ = fs::remove_file(&frame.path);
    }
}

// cuts `geometry` out of a frozen frame into the screenshots folder, and copies it
pub fn save_region(frame: &Path, geometry: &str) {
    let Some(target) = destination() else {
        return;
    };

    let saved = run(Command::new("magick")
        .arg(frame)
        .args(["-crop", geometry, "+repage"])
        .arg(&target));

    if saved {
        copy(&target);
    }
}

// a whole output straight from grim, with no overlay; none takes every output
pub fn save_output(output: Option<&str>) {
    let Some(target) = destination() else {
        return;
    };

    let mut grim = Command::new("grim");

    if let Some(output) = output {
        grim.args(["-o", output]);
    }

    if run(grim.arg(&target)) {
        copy(&target);
    }
}

fn copy(path: &Path) {
    let Ok(file) = File::open(path) else {
        return;
    };

    run(Command::new("wl-copy")
        .args(["--type", "image/png"])
        .stdin(file));
}

// says whether the program ran and succeeded; a failure is printed, never fatal
fn run(command: &mut Command) -> bool {
    match command.status() {
        Ok(status) if status.success() => true,

        Ok(status) => {
            eprintln!("yohaku: {:?} failed with {status}", command.get_program());
            false
        }

        Err(error) => {
            eprintln!(
                "yohaku: failed to start {:?}: {error}",
                command.get_program()
            );
            false
        }
    }
}

fn picture_size(path: &Path) -> Option<(u32, u32)> {
    let mut header = [0u8; PNG_HEADER];

    File::open(path).ok()?.read_exact(&mut header).ok()?;

    region::png_size(&header)
}

// memory-backed and the user's own; frames are large, and private
fn frozen_folder() -> PathBuf {
    env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(env::temp_dir)
        .join("yohaku-screenshot")
}

/*
 * `~/Pictures/Screenshots/Screenshot from 2026-11-10 16-50-00.png`, the name
 * the older shots there already have; a second shot in the same second
 * gets a number instead of replacing the first
 */
fn destination() -> Option<PathBuf> {
    let Some(home) = env::var_os("HOME") else {
        eprintln!("yohaku: no HOME, nowhere to save the screenshot");
        return None;
    };

    let folder = PathBuf::from(home).join("Pictures/Screenshots");

    if let Err(error) = fs::create_dir_all(&folder) {
        eprintln!("yohaku: no screenshots folder: {error}");
        return None;
    }

    let stamp = Command::new("date")
        .arg("+%Y-%m-%d %H-%M-%S")
        .output()
        .ok()
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .filter(|stamp| !stamp.is_empty())
        .unwrap_or_else(|| String::from("now"));

    (1..)
        .map(|count| match count {
            1 => folder.join(format!("Screenshot from {stamp}.png")),
            _ => folder.join(format!("Screenshot from {stamp} ({count}).png")),
        })
        .find(|path| !path.exists())
}
