mod bar;
mod clock;
mod compositor;
mod hover;
mod icons;
mod poster;
mod spotify;
mod stats;
mod theme;

use amane::{App, Service};

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

    App::new()
        .font(theme::MONO)
        .window_per_monitor(bar::view)
        .window_per_monitor(poster::view)
        .run();
}
