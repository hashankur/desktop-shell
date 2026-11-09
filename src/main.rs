mod bar;
mod clock;
mod compositor;
mod theme;

use amane::{App, Service};

use compositor::Desktop;
use theme::Scheme;

fn main() {
    // started before the first frame, so the bar opens with real data
    drop(Scheme::read());
    drop(Desktop::read());

    App::new()
        .font(theme::MONO)
        .window_per_monitor(bar::view)
        .run();
}
