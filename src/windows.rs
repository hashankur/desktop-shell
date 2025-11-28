use spell_framework::{
    cast_spell,
    layer_properties::{BoardType, LayerAnchor, LayerType, WindowConf},
    wayland_adapter::SpellWin,
};
use std::error::Error;

pub fn setup_bar() -> SpellWin {
    let window_conf = WindowConf::new(
        1920,
        40,
        (Some(LayerAnchor::TOP), None),
        (0, 0, 0, 0),
        LayerType::Top,
        BoardType::None,
        Some(40),
    );

    SpellWin::invoke_spell("bar", window_conf)
}

pub fn run_spell(waywindow: SpellWin) -> Result<(), Box<dyn Error>> {
    cast_spell(waywindow, None, None)
}
