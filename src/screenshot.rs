mod capture;
mod region;
mod view;

use std::thread;

use amane::{Button, Key, Point, Service};

use crate::compositor;
use crate::theme;

use capture::Frozen;
use region::Area;

pub use view::view;

/*
 * a region screenshot freezes every output first: each gets a still frame
 * of itself, drawn over everything, and the box is drawn on that. the shot
 * is cut from the frame, so the overlay can never end up in it. a whole
 * output skips all that and goes straight to grim. everything starts
 * empty, so a reload never comes up frozen
 */
#[derive(Default)]
pub struct Screenshot {
    // a still frame per output while a region is chosen; empty the rest of the time
    frozen: Vec<Frozen>,

    // where the capture was asked for, which takes the keyboard
    focus: Option<String>,

    selection: Option<Selection>,

    // the frames are still being taken
    freezing: bool,

    /*
     * counts every start and cancel, so frames that finish after a cancel,
     * or after a newer capture started, are thrown away instead of shown
     */
    generation: u64,
}

// the box being drawn, on one output
#[derive(Clone, PartialEq)]
struct Selection {
    output: String,
    start: Point,
    end: Point,

    // the output's size in window units
    bounds: (f32, f32),

    // the button is still down
    dragging: bool,
}

impl Selection {
    fn area(&self) -> Area {
        region::between(self.start, self.end, self.bounds)
    }
}

impl Service for Screenshot {
    fn new() -> Self {
        Self::default()
    }

    // only changes through ipc, keys and the pointer
    fn listen() {}
}

impl Screenshot {
    fn active(&self) -> bool {
        self.freezing || !self.frozen.is_empty()
    }

    fn frame(&self, output: &str) -> Option<&Frozen> {
        self.frozen.iter().find(|frame| frame.output == output)
    }

    // the focused output when it has a frame, otherwise the first that does
    fn keyboard_output(&self) -> Option<&str> {
        let focus = self
            .focus
            .as_deref()
            .filter(|focus| self.frame(focus).is_some());

        focus.or_else(|| self.frozen.first().map(|frame| frame.output.as_str()))
    }

    // the box drawn on this output, if any
    fn area_on(&self, output: &str) -> Option<Area> {
        self.selection
            .as_ref()
            .filter(|selection| selection.output == output)
            .map(Selection::area)
    }
}

/*
 * freezes the outputs and lets a box be drawn. asked again while that is
 * going on, it cancels instead, so the same key always gets out
 */
fn region() {
    // read before taking the lock for writing, since they read other services
    let outputs = compositor::outputs();
    let focus = compositor::focused_output();

    let generation = {
        let mut shot = Screenshot::write();

        if shot.active() {
            drop(shot);
            cancel();
            return;
        }

        shot.generation += 1;
        shot.freezing = true;
        shot.generation
    };

    thread::spawn(move || {
        let frozen = capture::freeze(&outputs);

        let mut shot = Screenshot::write();

        // cancelled, or replaced, while the frames were being taken
        if shot.generation != generation {
            drop(shot);

            if let Some(frozen) = frozen {
                capture::discard(&frozen);
            }

            return;
        }

        shot.freezing = false;

        if let Some(frozen) = frozen {
            shot.frozen = frozen;
            shot.focus = focus;
            shot.selection = None;
        }
    });
}

fn cancel() {
    let frozen = {
        let mut shot = Screenshot::write();

        if !shot.active() {
            return;
        }

        shot.generation += 1;
        shot.freezing = false;
        shot.focus = None;
        shot.selection = None;

        std::mem::take(&mut shot.frozen)
    };

    capture::discard(&frozen);
}

/*
 * cuts the box out of its output's frame; with no box it takes the whole
 * keyboard output. the overlay goes at once, the saving happens after
 */
fn take() {
    let (frozen, target) = {
        let mut shot = Screenshot::write();

        if shot.frozen.is_empty() {
            return;
        }

        // a box too small to mean anything counts as no box
        let selection = shot
            .selection
            .as_ref()
            .filter(|selection| selection.area().is_at_least(theme::shot::MIN));

        let target = match selection {
            Some(selection) => Some((
                selection.output.clone(),
                Some((selection.area(), selection.bounds)),
            )),
            None => shot
                .keyboard_output()
                .map(|output| (output.to_string(), None)),
        };

        shot.generation += 1;
        shot.focus = None;
        shot.selection = None;

        (std::mem::take(&mut shot.frozen), target)
    };

    thread::spawn(move || {
        let cut = target.and_then(|(output, area)| {
            let frame = frozen.iter().find(|frame| frame.output == output)?;

            // with no box, the whole frame as it is
            let (area, bounds) = area.unwrap_or_else(|| {
                let bounds = (frame.size.0 as f32, frame.size.1 as f32);

                (Area::whole(bounds), bounds)
            });

            Some((frame, region::crop(area, bounds, frame.size)?))
        });

        if let Some((frame, crop)) = cut {
            capture::save_region(&frame.path, &crop);
        }

        capture::discard(&frozen);
    });
}

// a left press and every move until the release
fn drag(output: &str, bounds: (f32, f32), point: Point) {
    let mut shot = Screenshot::write();

    match &mut shot.selection {
        // still the same drag
        Some(selection) if selection.dragging && selection.output == output => {
            if selection.end != point {
                selection.end = point;
            }
        }

        // a press starts a new box, wherever the last one was
        _ => {
            shot.selection = Some(Selection {
                output: output.to_string(),
                start: point,
                end: point,
                bounds,
                dragging: true,
            });
        }
    }
}

// a left release on the output the drag started on takes the box, unless it was only a click
fn release(output: &str) {
    let big_enough = {
        let mut shot = Screenshot::write();

        let Some(selection) = shot
            .selection
            .as_mut()
            .filter(|selection| selection.output == output)
        else {
            return;
        };

        selection.dragging = false;
        selection.area().is_at_least(theme::shot::MIN)
    };

    if big_enough {
        take();
    }
}

// the pointer left mid-drag, so no release will come; the box stays, and enter takes it
fn leave(output: &str) {
    let dragging = Screenshot::read()
        .selection
        .as_ref()
        .is_some_and(|selection| selection.dragging && selection.output == output);

    if dragging && let Some(selection) = Screenshot::write().selection.as_mut() {
        selection.dragging = false;
    }
}

fn click(output: &str, button: Button) {
    match button {
        Button::Left => release(output),
        Button::Right => cancel(),
        _ => {}
    }
}

fn key(key: Key) {
    match key {
        Key::Escape => cancel(),
        Key::Enter => take(),
        _ => {}
    }
}

/*
 * `amane ipc call screenshot [region|screen|cancel]`: region (the default)
 * freezes the outputs and takes a box drawn on them, screen takes the
 * focused output as it is. both save to ~/Pictures/Screenshots and copy
 */
pub fn ipc(arguments: &[String]) -> String {
    match arguments.first().map(String::as_str).unwrap_or("region") {
        "region" => region(),

        "screen" => {
            let output = compositor::focused_output();

            thread::spawn(move || capture::save_output(output.as_deref()));
        }

        "cancel" => cancel(),

        _ => return String::from("usage: screenshot [region|screen|cancel]"),
    }

    String::from("ok")
}
