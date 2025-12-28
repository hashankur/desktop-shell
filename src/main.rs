// #[derive(Debug, Clone)]
// enum SystemState {
//     FocusedWorkspace { id: i32 },
//     Workspaces(Vec<Workspace>),
// }

use std::env;
use std::path::PathBuf;
use std::time::{Duration, Instant};

use chrono::Local;
use layer_shika::calloop::TimeoutAction;
use layer_shika::prelude::*;
use layer_shika::slint::SharedString;
use layer_shika::slint_interpreter::Value;
use layer_shika::{AnchorEdges, Shell, Surface};

fn main() -> Result<()> {
    env::set_var("SLINT_STYLE", "cosmic-dark");

    env_logger::builder()
        .filter_level(log::LevelFilter::Info)
        .init();

    let ui_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("ui/app-window.slint");

    let mut shell = Shell::from_file(ui_path)
        .surface("Bar")
        .height(42)
        .anchor(AnchorEdges::top_bar())
        .exclusive_zone(42)
        .namespace("bar")
        .build()?;

    shell
        .select(Surface::named("Bar"))
        .with_component(|component| {
            let set_property = |name: &str, value: Value| {
                if let Err(e) = component.set_property(name, value) {
                    log::error!("Failed to set initial {}: {}", name, e);
                }
            };

            // set_property("test", SharedString::from("bello").into());
        });

    let handle = shell.event_loop_handle();

    handle.add_timer(Duration::from_secs(1), |_instant, app_state| {
        let time_str = current_time_string();

        for surface in app_state.all_outputs() {
            if let Err(e) = surface.component_instance().set_global_property(
                "State",
                "sys_time",
                Value::from(SharedString::from(time_str.clone())),
            ) {
                log::error!("Failed to set time property: {e}");
            }
        }

        TimeoutAction::ToInstant(Instant::now() + Duration::from_secs(1))
    })?;

    shell.run()?;

    Ok(())
}

fn current_time_string() -> String {
    let now = Local::now();
    now.format("%a %d %b  •  %I:%M %p").to_string()
}
