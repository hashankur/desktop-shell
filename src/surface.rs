mod clipboard;
mod launcher;
mod list;
mod power;
mod search;

use amane::{
    Full, Key, Keyboard, Layer, LayerWindow, Monitor, Parent, Rectangle, Service, Stack, Widget,
    Zone,
};

use crate::compositor;
use crate::motion;
use crate::theme::{self, SCRIM_OPACITY};

// the full-screen surfaces; more are added here as they are built
#[derive(Clone, Copy, PartialEq)]
pub enum Kind {
    Launcher,
    Clipboard,
    Power,
}

/*
 * which surface is open, and on which output. only one is open at a time:
 * opening one replaces any other. everything starts closed, so a reload
 * never comes up with a surface holding the keyboard
 */
#[derive(Default)]
pub struct Surface {
    open: Option<Kind>,

    // the one that was open last, still drawn while it fades out
    last: Option<Kind>,

    // the output it opened on; none shows it on every output. kept after closing, for the fade-out
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
        self.open.is_some() && self.on_output(monitor)
    }

    // whether this output is where the surface is, open or fading out
    fn on_output(&self, monitor: &str) -> bool {
        self.output.as_deref().is_none_or(|output| output == monitor)
    }

    pub fn open(kind: Kind) {
        // asked before taking the lock for writing, since it reads other services
        let output = compositor::focused_output();

        match kind {
            Kind::Launcher => list::reset(),

            Kind::Power => power::reset(),

            Kind::Clipboard => {
                list::reset();
                clipboard::refresh();
            }
        }

        let mut surface = Self::write();

        surface.open = Some(kind);
        surface.last = Some(kind);
        surface.output = output;
    }

    pub fn close() {
        let mut surface = Self::write();

        // the output is kept: the fade-out still happens where it was open
        surface.open = None;
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
 * shown on the output the surface opened on, and only there takes the
 * keyboard. closing fades it out first, so the window stays shown, and
 * click-through, until the fade has finished
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let surface = Surface::read();
    let (open, last) = (surface.open, surface.last);
    let (here, on_output) = (surface.shows(&monitor.name), surface.on_output(&monitor.name));
    drop(surface);

    let motion = motion::presence(&format!("surface/{}", monitor.name), here);

    let drawn = on_output && (here || motion.moving);

    // the surface still fading out is the one that was open
    let content = match open.or(last) {
        Some(Kind::Launcher) if drawn => launcher::view(&theme, monitor),
        Some(Kind::Clipboard) if drawn => clipboard::view(&theme, monitor),
        Some(Kind::Power) if drawn => power::view(&theme, monitor),
        _ => Rectangle::new().width(Parent).height(Parent),
    };

    // the empty space is the backdrop, so clicking it closes
    let scrim = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .fill(theme::faded(theme.scrim, SCRIM_OPACITY * motion.scrim))
        .on_click(|_| Surface::close());

    let content = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .opacity(motion.content)
        .translate(0.0, motion.shift)
        .child(content);

    let window = LayerWindow::new()
        .width(Full)
        .height(Full)
        .layer(Layer::Overlay)
        .space(Zone::Respect)
        .namespace("yohaku-surface")
        .visible(drawn)
        .keyboard(if here {
            Keyboard::Exclusive
        } else {
            Keyboard::None
        })
        .on_key(key)
        .child(Stack::new(vec![Box::new(scrim) as Box<dyn Widget>, Box::new(content)]));

    // while it fades out, a click belongs to the windows below
    if here { window } else { window.click_through() }
}

// escape closes, except where a surface has something to cancel first; every other key is the open surface's
fn key(key: Key) {
    let open = Surface::read().open;

    if key == Key::Escape {
        let cancelled = match open {
            Some(Kind::Power) => power::escape(),
            _ => false,
        };

        if !cancelled {
            Surface::close();
        }

        return;
    }

    match open {
        Some(Kind::Launcher) => launcher::key(key),
        Some(Kind::Clipboard) => clipboard::key(key),
        Some(Kind::Power) => power::key(key),
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

// `amane ipc call clipboard [toggle|show|hide]`
pub fn clipboard_ipc(arguments: &[String]) -> String {
    command(Kind::Clipboard, arguments)
}

// `amane ipc call power [toggle|show|hide]`
pub fn power_ipc(arguments: &[String]) -> String {
    command(Kind::Power, arguments)
}
