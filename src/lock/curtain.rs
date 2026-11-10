use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant};

use amane::{
    Full, Layer, LayerWindow, Lock, Monitor, Parent, Rectangle, Service, Vertical, Zone,
};

use crate::motion::{self, Presence};
use crate::theme::{self, timing};

// how often a pam check in progress is looked at
const PAM_POLL: Duration = Duration::from_millis(50);

// how often, and for how long, the watchdog looks for a drawn lock screen
const LOCK_POLL: Duration = Duration::from_millis(100);
const LOCK_GIVE_UP: Duration = Duration::from_secs(10);

// set by the lock screen's view once it has drawn, so the watchdog knows the lock took
static LOCK_DRAWN: AtomicBool = AtomicBool::new(false);

/*
 * the desktop around a lock: the bar and poster leave first, then a cover
 * in the lock screen's own color comes over everything, and only then is
 * the session locked, so the lock screen opens without a seam. unlocking
 * plays it backwards: the cover lifts, and the bar and poster follow a beat
 * later. it is the same timeline every surface uses: "shown" is the desktop,
 * the scrim is the cover's absence and the content is the bar and poster
 */
pub struct Curtain {
    // the desktop is shown; false from the start of a lock until it is undone
    shown: bool,
}

impl Service for Curtain {
    fn new() -> Self {
        Self { shown: true }
    }

    // only changes when locking and unlocking
    fn listen() {}
}

// one frame of the curtain, for the bar, the poster and the cover; all share one timeline
pub fn presence() -> Presence {
    let shown = Curtain::read().shown;

    motion::presence("curtain", shown)
}

// how opaque the bar and poster are right now, 1 outside a lock
pub fn items() -> f32 {
    presence().content
}

// the lock screen calls this when it draws, so a lock that took is told apart from one refused
pub fn note_lock_drawn() {
    LOCK_DRAWN.store(true, Ordering::Relaxed);
}

/*
 * closes the curtain, then locks; blocks for the length of the fade, so it
 * runs on its own thread. a lock already on its way is left alone
 */
pub fn close_then_lock() {
    {
        let mut curtain = Curtain::write();

        if !curtain.shown {
            return;
        }

        curtain.shown = false;
    }

    LOCK_DRAWN.store(false, Ordering::Relaxed);

    // the bar and poster leave, then the cover follows a beat later
    thread::sleep(Duration::from_secs_f32(timing::BEAT + timing::OUT));

    Lock::start();

    watch_for_refusal();
}

/*
 * a compositor that refuses the lock never shows a lock screen, and the
 * cover would then hide the desktop without locking it. if no lock screen
 * has drawn in time, the curtain opens again
 */
fn watch_for_refusal() {
    let started = Instant::now();

    while started.elapsed() < LOCK_GIVE_UP {
        if LOCK_DRAWN.load(Ordering::Relaxed) {
            return;
        }

        thread::sleep(LOCK_POLL);
    }

    eprintln!("yohaku: no lock screen appeared, so the curtain is lifted again");

    Curtain::write().shown = true;
}

// waits on pam, then opens the curtain if the password was right; runs on its own thread
pub fn open_when_accepted() {
    while Lock::read().checking() {
        thread::sleep(PAM_POLL);
    }

    if Lock::read().failed() {
        return;
    }

    LOCK_DRAWN.store(false, Ordering::Relaxed);

    Curtain::write().shown = true;
}

/*
 * the cover itself: one window per output, over everything including the
 * bar, in the lock screen's background color. it only exists on screen
 * while a lock is coming or going, and never takes the pointer
 */
pub fn view(_monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let curtain = presence();

    let cover = 1.0 - curtain.scrim;

    LayerWindow::new()
        .width(Full)
        .height(Full)
        .anchor_vertical(Vertical::Top)
        .layer(Layer::Overlay)
        // over the bar's reserved space too
        .space(Zone::Ignore)
        .namespace("yohaku-curtain")
        .click_through()
        .visible(cover > 0.0 || curtain.moving)
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .fill(theme::faded(theme.surface, cover)),
        )
}
