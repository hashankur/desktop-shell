mod bar;
mod clock;
mod compositor;
mod hover;
mod icons;
mod poster;
mod spotify;
mod stats;
mod surface;
mod text;
mod theme;

use amane::{App, Apps, Service};

use compositor::Desktop;
use icons::Icons;
use stats::Sensors;
use theme::Scheme;

fn main() {
    // started before the first frame, so the bar opens with real data
    drop(Scheme::read());
    drop(Desktop::read());
    drop(Sensors::read());
    drop(Icons::read());
    // the app scan takes seconds, so it starts before the launcher is first opened
    drop(Apps::read());

    App::new()
        .font(theme::MONO)
        .window_per_monitor(bar::view)
        .window_per_monitor(poster::view)
        .window_per_monitor(surface::view)
        .ipc("launcher", surface::launcher_ipc)
        .run();
}
