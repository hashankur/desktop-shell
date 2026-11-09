pub mod launcher;

use amane::{
    Full, Key, Keyboard, Layer, LayerWindow, Monitor, Parent, Rectangle, Service, Stack, Widget,
    Zone,
};

use crate::compositor;
use crate::theme::{self, SCRIM_OPACITY};

// the full-screen surfaces; more are added here as they are built
#[derive(Clone, Copy, PartialEq)]
pub enum Kind {
    Launcher,
}

/*
 * which surface is open, and on which output. only one is open at a time:
 * opening one replaces any other. everything starts closed, so a reload
 * never comes up with a surface holding the keyboard
 */
#[derive(Default)]
pub struct Surface {
    open: Option<Kind>,

    // the output it opened on; none shows it on every output
    output: Option<String>,
}

impl Service for Surface {
    fn new() -> Self {
        Self::default()
    }

    // only changes through ipc, keys and clicks
    fn listen() {}
}

impl Surface {
    fn shows(&self, monitor: &str) -> bool {
        self.open.is_some() && self.output.as_deref().is_none_or(|output| output == monitor)
    }

    pub fn open(kind: Kind) {
        // asked before taking the lock for writing, since it reads other services
        let output = compositor::focused_output();

        match kind {
            Kind::Launcher => launcher::reset(),
        }

        let mut surface = Self::write();

        surface.open = Some(kind);
        surface.output = output;
    }

    pub fn close() {
        let mut surface = Self::write();

        surface.open = None;
        surface.output = None;
    }

    pub fn toggle(kind: Kind) {
        let open = Self::read().open;

        if open == Some(kind) {
            Self::close();
        } else {
            Self::open(kind);
        }
    }
}

/*
 * one window per output, on the overlay layer below the bar: a scrim over
 * the windows behind and the open surface's content on it. it is only
 * shown on the output the surface opened on, and only then takes the keyboard
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let surface = Surface::read();
    let (open, shown) = (surface.open, surface.shows(&monitor.name));
    drop(surface);

    let content: Box<dyn Widget> = match open {
        Some(Kind::Launcher) if shown => Box::new(launcher::view(&theme, monitor)),
        _ => Box::new(Rectangle::new().width(Parent).height(Parent)),
    };

    // the empty space is the backdrop, so clicking it closes
    let scrim = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .fill(theme::faded(theme.scrim, SCRIM_OPACITY))
        .on_click(|_| Surface::close());

    LayerWindow::new()
        .width(Full)
        .height(Full)
        .layer(Layer::Overlay)
        .space(Zone::Respect)
        .namespace("yohaku-surface")
        .visible(shown)
        .keyboard(if shown {
            Keyboard::Exclusive
        } else {
            Keyboard::None
        })
        .on_key(key)
        .child(Stack::new(vec![Box::new(scrim) as Box<dyn Widget>, content]))
}

// escape always closes; every other key belongs to the open surface
fn key(key: Key) {
    if key == Key::Escape {
        Surface::close();

        return;
    }

    let open = Surface::read().open;

    match open {
        Some(Kind::Launcher) => launcher::key(key),
        None => {}
    }
}

// `amane ipc call launcher [toggle|show|hide]`
pub fn launcher_ipc(arguments: &[String]) -> String {
    command(Kind::Launcher, arguments)
}

fn command(kind: Kind, arguments: &[String]) -> String {
    match arguments.first().map(String::as_str).unwrap_or("toggle") {
        "show" => Surface::open(kind),

        "hide" => {
            if Surface::read().open == Some(kind) {
                Surface::close();
            }
        }

        _ => Surface::toggle(kind),
    }

    String::from("ok")
}
