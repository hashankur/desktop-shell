slint::include_modules!();

mod bar;
mod windows;

use chrono::Local;
use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    let window_list = windows::setup();
    let ui = Bar::new().unwrap();

    let ui_weak = ui.as_weak();

    ui.global::<State>().on_dateTime(move || {
        let now = Local::now();
        let formatted = now.format("%a %d %b  •  %I:%M %p").to_string();
        formatted.into()
    });

    bar::counter::setup(&ui);

    windows::run_spells(window_list)
}
