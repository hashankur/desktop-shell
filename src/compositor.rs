mod umbriel;

use std::env;
use std::thread;
use std::time::Duration;

use amane::{Service, Workspaces};

/*
 * what the shell knows about the compositor: workspaces per output and
 * the focused window. umbriel is read here, since amane's own compositor
 * module has no umbriel backend; niri comes from amane's Workspaces
 */
#[derive(Default)]
pub struct Desktop {
    pub(crate) spaces: Vec<Space>,
    pub(crate) focused: Option<Focused>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Space {
    pub index: u32,
    pub name: String,
    pub output: String,
    pub active: bool,
    pub focused: bool,
    pub occupied: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Focused {
    pub app_id: String,
    pub title: String,
}

#[derive(Clone, Copy, PartialEq)]
enum Backend {
    Umbriel,
    Niri,
}

// each compositor sets its own variable for the programs it starts
fn backend() -> Option<Backend> {
    if env::var_os("UMBRIEL_SOCKET").is_some() {
        return Some(Backend::Umbriel);
    }

    if env::var_os("NIRI_SOCKET").is_some() {
        return Some(Backend::Niri);
    }

    None
}

impl Service for Desktop {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        if backend() != Some(Backend::Umbriel) {
            return;
        }

        // the stream ends when umbriel restarts or the pipe breaks; never give up on it
        let mut wait = Duration::from_millis(500);

        loop {
            let heard = umbriel::follow();

            wait = if heard {
                Duration::from_millis(500)
            } else {
                (wait * 2).min(Duration::from_secs(10))
            };

            thread::sleep(wait);
        }
    }
}

impl Desktop {
    pub fn focused(&self) -> Option<&Focused> {
        self.focused.as_ref()
    }
}

/*
 * the workspaces on one output, in order; called from a view, so it
 * subscribes the window to whichever service the backend uses
 */
pub fn spaces_on(output: &str) -> Vec<Space> {
    let mut spaces: Vec<Space> = match backend() {
        Some(Backend::Umbriel) => Desktop::read()
            .spaces
            .iter()
            .filter(|space| space.output == output)
            .cloned()
            .collect(),

        Some(Backend::Niri) => Workspaces::read()
            .list()
            .iter()
            .filter(|workspace| workspace.output() == Some(output))
            .map(|workspace| Space {
                index: workspace.index(),
                name: workspace
                    .name()
                    .map(str::to_string)
                    .unwrap_or_else(|| workspace.index().to_string()),
                output: output.to_string(),
                active: workspace.active(),
                focused: workspace.focused(),
                occupied: workspace.windows() > 0,
            })
            .collect(),

        None => Vec::new(),
    };

    spaces.sort_by_key(|space| space.index);

    spaces
}

pub fn switch_to(space: &Space) {
    match backend() {
        Some(Backend::Umbriel) => umbriel::switch_to(space),

        Some(Backend::Niri) => {
            // amane's niri backend focuses by id, which only it knows, so go through the index
            amane::spawn(&format!(
                "niri msg action focus-workspace {}",
                space.index
            ));
        }

        None => {}
    }
}
