mod bar;
mod clock;
mod compositor;
mod hover;
mod icons;
mod lock;
mod motion;
mod poster;
mod spotify;
mod stats;
mod surface;
mod text;
mod theme;

use amane::{App, Apps, Service};

use compositor::Desktop;
use icons::Icons;
use lock::Logind;
use stats::Sensors;
use theme::Scheme;

fn main() {
    // started before the first frame, so the bar opens with real data
    drop(Scheme::read());
    drop(Desktop::read());
    drop(Sensors::read());
    drop(Icons::read());
    // listens for logind asking to lock, like `loginctl lock-session` or an idle daemon
    drop(Logind::read());
    // the app scan takes seconds, so it starts before the launcher is first opened
    drop(Apps::read());

    App::new()
        .font(theme::MONO)
        .window_per_monitor(bar::view)
        .window_per_monitor(poster::view)
        .window_per_monitor(surface::view)
        .window_per_monitor(lock::curtain_view)
        .lock(lock::view)
        .ipc("launcher", surface::launcher_ipc)
        .ipc("clipboard", surface::clipboard_ipc)
        .ipc("power", surface::power_ipc)
        .ipc("lock", lock::ipc)
        .run();
}
