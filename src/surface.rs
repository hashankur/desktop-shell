mod clipboard;
mod cover;
mod dashboard;
mod launcher;
mod list;
mod power;
mod search;
mod settings;

use amane::{
    Full, Key, Keyboard, Layer, LayerWindow, Monitor, Padding, Parent, Rectangle, Service, Stack,
    Widget, Zone,
};

use crate::bar;
use crate::compositor;
use crate::lock;
use crate::theme::{self, SCRIM_OPACITY};

pub use cover::{bar_tint, cover};

// the full-screen surfaces; more are added here as they are built
#[derive(Clone, Copy, PartialEq)]
pub enum Kind {
    Launcher,
    Clipboard,
    Power,
    Dashboard,
    Settings,
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

        // opening one surface closes the other, so it gets to leave the same way
        if Self::read().open.is_some_and(|open| open != kind) {
            leave();
        }

        match kind {
            Kind::Launcher => list::reset(),

            Kind::Power => power::reset(),

            Kind::Dashboard => dashboard::refresh(),

            Kind::Settings => settings::reset(),

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
        leave();

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

// what the open surface stops when it goes, like a bluetooth scan
fn leave() {
    if Surface::read().open == Some(Kind::Settings) {
        settings::leave();
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
    drop(surface);

    let cover::Cover { here, drawn, motion } = cover(&monitor.name);

    // the dashboard and settings sit at the top, so they come down from above; the others rise into place
    let shift = match open.or(last) {
        Some(Kind::Dashboard | Kind::Settings) => -motion.shift,
        _ => motion.shift,
    };

    // the surface still fading out is the one that was open
    let content = match open.or(last) {
        Some(Kind::Launcher) if drawn => launcher::view(&theme, monitor),
        Some(Kind::Clipboard) if drawn => clipboard::view(&theme, monitor),
        Some(Kind::Power) if drawn => power::view(&theme, monitor),
        Some(Kind::Dashboard) if drawn => dashboard::view(&theme, monitor),
        Some(Kind::Settings) if drawn => settings::view(&theme, monitor),
        _ => Rectangle::new().width(Parent).height(Parent),
    };

    // the empty space is the backdrop, so clicking it closes
    let scrim = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .fill(theme::faded(theme.scrim, cover::surface_tint(SCRIM_OPACITY, motion.scrim)))
        .on_click(|_| Surface::close());

    // the window runs under the bar too, so the content starts below it, where it always has
    let content = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(Padding { top: theme::bar::HEIGHT, right: 0.0, bottom: 0.0, left: 0.0 })
        .opacity(motion.content)
        .translate(0.0, shift)
        .child(content);

    // the bar, drawn here while the window covers it; its own click is a no-op, so the empty bar does not close the surface
    let mut layers: Vec<Box<dyn Widget>> = vec![Box::new(scrim), Box::new(content)];

    if drawn {
        let tint = cover::strip_tint(SCRIM_OPACITY, motion.scrim);

        layers.push(Box::new(
            Rectangle::new()
                .width(Parent)
                .height(theme::bar::HEIGHT)
                .fill(theme::faded(theme.scrim, tint))
                .opacity(lock::curtain_items())
                .on_click(|_| {})
                .child(bar::strip(&monitor.name, &theme)),
        ));
    }

    let window = LayerWindow::new()
        .width(Full)
        .height(Full)
        .layer(Layer::Overlay)
        .space(Zone::Ignore)
        .namespace("yohaku-surface")
        .visible(drawn)
        .keyboard(if here {
            Keyboard::Exclusive
        } else {
            Keyboard::None
        })
        .on_key(key)
        .child(Stack::new(layers));

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
        Some(Kind::Settings) => settings::key(key),
        Some(Kind::Dashboard) => dashboard::key(key),
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

// `amane ipc call dashboard [toggle|show|hide]`
pub fn dashboard_ipc(arguments: &[String]) -> String {
    command(Kind::Dashboard, arguments)
}

// `amane ipc call settings [toggle|show|hide] [quick|network|bluetooth|appearance]`
pub fn settings_ipc(arguments: &[String]) -> String {
    let reply = command(Kind::Settings, arguments);

    // a page after the command opens settings on it, for a bind straight to the wifi list
    if let Some(page) = arguments.get(1)
        && Surface::read().open == Some(Kind::Settings)
    {
        settings::show_page(page);
    }

    reply
}
