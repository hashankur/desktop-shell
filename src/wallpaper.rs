mod matugen;

use std::fs;
use std::path::{Path, PathBuf};
use std::thread;

use amane::{
    Fill, Full, Image, Layer, LayerWindow, Monitor, Parent, Rectangle, Service, Vertical, Zone,
};

use crate::files;
use crate::theme;

/*
 * the picture behind everything, which yohaku draws itself. setting it and
 * coloring the shell after it are one step: matugen reads the picture and
 * the scheme it makes replaces the shell's colors live. the path is kept in
 * yohaku's state, so it is there again after a restart
 */
#[derive(Default)]
pub struct Wallpaper {
    path: Option<PathBuf>,
}

impl Service for Wallpaper {
    fn new() -> Self {
        Self { path: read_state() }
    }

    // follows the state file, so it changes after a set, or a hand edit, all the same
    fn listen() {
        let state = state_path();

        // the folder has to exist before it can be watched
        if let Some(folder) = state.parent() {
            let _ = fs::create_dir_all(folder);
        }

        for _ in amane::watch_file(&state.to_string_lossy()) {
            let path = read_state();

            if Self::read().path != path {
                Self::write().path = path;
            }
        }
    }
}

fn state_path() -> PathBuf {
    theme::state_folder().join("wallpaper")
}

fn read_state() -> Option<PathBuf> {
    let text = fs::read_to_string(state_path()).ok()?;
    let path = text.trim();

    (!path.is_empty()).then(|| PathBuf::from(path))
}

/*
 * one window per output on the background layer, under everything, over the
 * bar's strip too. until a wallpaper has been set it stays hidden, so whatever
 * drew the background before still shows
 */
pub fn view(_monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let path = Wallpaper::read().path.clone();

    let fill: Fill = match &path {
        Some(path) => Image::cover(path).into(),
        None => theme.surface.into(),
    };

    LayerWindow::new()
        .width(Full)
        .height(Full)
        .anchor_vertical(Vertical::Top)
        .layer(Layer::Background)
        .space(Zone::Ignore)
        .namespace("yohaku-wallpaper")
        .click_through()
        .visible(path.is_some())
        .child(Rectangle::new().width(Parent).height(Parent).fill(fill))
}

/*
 * matugen first, so the colors are ready when the picture changes; a picture
 * matugen can't read still becomes the wallpaper, with the colors left as they
 * were. runs on its own thread, matugen takes a moment
 */
fn apply(path: PathBuf) {
    match matugen::scheme(&path) {
        Some(scheme) => {
            if let Err(error) = files::write_atomic(&theme::scheme_path(), &scheme) {
                eprintln!("yohaku: failed to save the color scheme: {error}");
            }
        }

        None => eprintln!("yohaku: kept the colors, matugen gave nothing for {}", path.display()),
    }

    let line = format!("{}\n", path.display());

    if let Err(error) = files::write_atomic(&state_path(), &line) {
        eprintln!("yohaku: failed to save the wallpaper: {error}");
    }
}

/*
 * `amane ipc call wallpaper set <path>` sets it; `amane ipc call wallpaper`
 * prints the current one
 */
pub fn ipc(arguments: &[String]) -> String {
    match arguments {
        [] => Wallpaper::read()
            .path
            .as_ref()
            .map_or_else(|| String::from("none"), |path| path.display().to_string()),

        [command, path] if command == "set" => set(Path::new(path)),

        _ => String::from("usage: wallpaper [set <path>]"),
    }
}

fn set(path: &Path) -> String {
    // an absolute path, so the state still means the same file from anywhere
    let Ok(path) = fs::canonicalize(path) else {
        return format!("no such file: {}", path.display());
    };

    if !path.is_file() {
        return format!("not a file: {}", path.display());
    }

    thread::spawn(move || apply(path));

    String::from("ok")
}
