use chrono::Local;
use slint::{ComponentHandle, Timer, TimerMode};
use spell_framework::{
    cast_spell,
    layer_properties::{BoardType, LayerAnchor, LayerType, WindowConf},
    wayland_adapter::SpellWin,
};
use std::{env, error::Error};
slint::include_modules!();

fn main() -> Result<(), Box<dyn Error>> {
    let window_conf = WindowConf::new(
        1920,
        40,
        (Some(LayerAnchor::TOP), None),
        (0, 0, 0, 0),
        LayerType::Top,
        BoardType::None,
        Some(40),
    );

    let waywindow = SpellWin::invoke_spell("counter-widget", window_conf);
    let ui = AppWindow::new().unwrap();
    ui.on_request_increase_value({
        let ui_handle = ui.as_weak();
        move || {
            let ui = ui_handle.unwrap();
            ui.set_counter(ui.get_counter() + 1);
        }
    });
    let timer = Timer::default();
    timer.start(TimerMode::Repeated, std::time::Duration::from_secs(1), {
        let ui_handle = ui.as_weak();
        move || {
            let ui = ui_handle.unwrap();
            let now = Local::now();
            let formatted = now.format("%a %d %b  •  %I:%M %p").to_string();
            ui.set_sys_time(formatted.into());
        }
    });

    cast_spell(waywindow, None, None)
}
