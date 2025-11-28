slint::include_modules!();

mod bar;
mod windows;

use chrono::Local;
use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    let waywindow = windows::setup_bar();
    let ui = AppWindow::new().unwrap();

    ui.global::<State>().on_dateTime(move || {
        let now = Local::now();
        let formatted = now.format("%a %d %b  •  %I:%M %p").to_string();
        formatted.into()
    });

    bar::counter::setup(&ui);
    // Remove any Rust timer logic that set system time directly.

    windows::run_spell(waywindow)
}
