mod bar;
mod clock;
mod compositor;
mod stats;
mod theme;

use amane::{App, Service};

use compositor::Desktop;
use stats::Sensors;
use theme::Scheme;

fn main() {
    // started before the first frame, so the bar opens with real data
    drop(Scheme::read());
    drop(Desktop::read());
    drop(Sensors::read());

    App::new()
        .font(theme::MONO)
        .window_per_monitor(bar::view)
        .run();
}
