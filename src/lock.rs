mod curtain;
mod logind;
mod password;

use std::thread;

use amane::{End, LayerWindow, Monitor, Padding, Parent, Rectangle, Stack, Start, Widget};

use crate::poster;
use crate::theme::{self, grid};

pub use curtain::{items as curtain_items, view as curtain_view};
pub use logind::Logind;

/*
 * what every monitor shows while the session is locked. amane takes the
 * compositor's session lock and only lets go once pam accepts the password,
 * so this is only the picture: the time and date as on the poster, large at
 * the top left, and the password prompt bottom left, where the launcher sits.
 * the lock covers everything, so there is no bar and no desktop behind it
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let width = grid::span(4, monitor.width as f32);

    let margin = Padding {
        top: grid::MARGIN,
        right: grid::MARGIN,
        bottom: grid::MARGIN,
        left: grid::MARGIN,
    };

    let background = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .fill(theme.surface);

    let time = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(margin)
        .child(poster::time_and_date(&theme));

    let prompt = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(margin)
        .align_child(Start, End)
        .child(password::view(&theme, width));

    // drawing at all means the compositor granted the lock, which the curtain waits to hear
    curtain::note_lock_drawn();

    // the compositor sizes lock screens to the monitor, so the window's own size is never used
    LayerWindow::new()
        .width(1.0)
        .height(1.0)
        .child(Stack::new(vec![
            Box::new(background) as Box<dyn Widget>,
            Box::new(time),
            Box::new(prompt),
        ]))
}

/*
 * locks the session behind the curtain: the desktop fades out first and the
 * lock starts once it has. does nothing while a lock is already on its way.
 * every lock opens on an empty field
 */
pub fn start() {
    password::clear();

    thread::spawn(curtain::close_then_lock);
}

// `amane ipc call lock`, the same as `loginctl lock-session`
pub fn ipc(_arguments: &[String]) -> String {
    start();

    String::from("ok")
}
