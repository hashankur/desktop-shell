slint::include_modules!();

mod bar;
mod niri;
mod windows;

use chrono::Local;
use slint::{ModelRc, VecModel};
use std::{error::Error, rc::Rc, sync::mpsc::channel, thread, time::Duration};
use tokio::{join, runtime::Runtime};

use crate::niri::niri_event_listener;

#[derive(Debug, Clone)]
enum SystemState {
    FocusedWorkspace {
        id: i32,
    },
    Workspaces(Vec<Workspace>),
}

fn main() -> Result<(), Box<dyn Error>> {
    let window_list = windows::setup();

    let (tx, rx) = channel::<SystemState>();
    let ui = Bar::new().unwrap();
    let ui_weak = ui.as_weak();

    ui.global::<State>().on_dateTime(move || {
        let now = Local::now();
        let formatted = now.format("%a %d %b  •  %I:%M %p").to_string();
        formatted.into()
    });

    thread::spawn(move || {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            join!(
                // IPC
                niri_event_listener(tx.clone())
            )
        })
    });

    let timer = slint::Timer::default();
    timer.start(
        slint::TimerMode::Repeated,
        Duration::from_millis(50),
        move || {
            // Process all available updates from Tokio
            while let Ok(update) = rx.try_recv() {
                if let Some(ui) = ui_weak.upgrade() {
                    match update {
                        SystemState::FocusedWorkspace { id } => {
                            ui.global::<State>().set_workspaceFocused(id);
                        }
                        SystemState::Workspaces(mut workspaces) => {
                            workspaces.sort_by_key(|ws| ws.id);
                            let vec_model = VecModel::from(workspaces);
                            let model_handle: ModelRc<Workspace> =
                                ModelRc::from(Rc::new(vec_model));
                            ui.global::<State>().set_workspaces(model_handle);
                        }
                        _ => {}
                    }
                }
            }
        },
    );

    bar::counter::setup(&ui);

    windows::run_spells(window_list)
}
