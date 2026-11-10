mod actions;
mod view;

use amane::{Key, Service};

use super::Surface;

pub use view::view;

/*
 * which action is chosen, and whether it has been picked and now waits for
 * its confirmation. only one surface is open at a time, so this starts over
 * every time the power surface opens
 */
#[derive(Default)]
pub struct Power {
    selected: usize,
    pending: bool,
}

impl Service for Power {
    fn new() -> Self {
        Self::default()
    }

    // only changes through keys and clicks
    fn listen() {}
}

pub fn reset() {
    *Power::write() = Power::default();
}

// picking an action: lock runs at once, the rest wait for enter
fn choose(index: usize) {
    let Some(action) = actions::ALL.get(index).copied() else {
        return;
    };

    if action.needs_confirm() {
        let mut power = Power::write();

        power.selected = index;
        power.pending = true;

        return;
    }

    run(action);
}

fn run(action: actions::Action) {
    // closed first, so the surface's fade doesn't hold the screen while the action starts
    Surface::close();

    action.run();
}

// the first escape cancels a waiting confirmation; true when it did, so the surface stays open
pub fn escape() -> bool {
    let mut power = Power::write();

    let was_pending = power.pending;

    power.pending = false;

    was_pending
}

pub fn key(key: Key) {
    let mut power = Power::write();

    let count = actions::ALL.len();

    match key {
        Key::Right if !power.pending => power.selected = (power.selected + 1) % count,

        Key::Left if !power.pending => power.selected = (power.selected + count - 1) % count,

        Key::Enter => {
            let (selected, pending) = (power.selected, power.pending);

            // choosing and running write other services, and close the surface
            drop(power);

            if pending {
                run(actions::ALL[selected]);
            } else {
                choose(selected);
            }
        }

        _ => {}
    }
}
