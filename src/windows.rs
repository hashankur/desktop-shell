use spell_framework::{
    enchant_spells,
    layer_properties::{BoardType, LayerAnchor, LayerType, WindowConf},
    slint_adapter::SpellMultiWinHandler,
    wayland_adapter::SpellWin,
};
use std::error::Error;

pub fn setup() -> Vec<SpellWin> {
    let windows = SpellMultiWinHandler::conjure_spells(vec![(
        "top-bar",
        WindowConf::new(
            1920,
            40,
            (Some(LayerAnchor::TOP), None),
            (0, 0, 0, 0),
            LayerType::Top,
            BoardType::None,
            Some(30),
        ),
    )]);

    windows
}

pub fn run_spells(windows: Vec<SpellWin>) -> Result<(), Box<dyn Error>> {
    enchant_spells(windows, vec![None], vec![None])
}
