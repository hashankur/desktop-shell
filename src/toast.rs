mod content;

use std::thread;
use std::time::{Duration, SystemTime};

use amane::{
    Button, Horizontal, InputArea, Layer, LayerWindow, Monitor, Notification, Notifications, Parent,
    Pointer, Rectangle, Service, Shadow, Size, Stack, Urgency, Vertical, Widget, Zone,
};

use crate::compositor;
use crate::hover;
use crate::motion;
use crate::theme::{self, SCRIM_OPACITY, grid, timing, toast};

// how often the toast checks whether the newest notification should still show
const POLL: Duration = Duration::from_millis(250);

/*
 * which notification the toast shows: the newest one that is still fresh,
 * or a critical one, which stays until it is dealt with. a toast under the
 * pointer stays too. the notification itself stays in the list after its
 * toast goes, for the bar's count and, later, the dashboard
 */
#[derive(Default)]
pub struct Toast {
    shown: Option<Notification>,

    // the one shown last, still drawn while it fades out
    last: Option<Notification>,
}

impl Service for Toast {
    fn new() -> Self {
        Self::default()
    }

    // the time a toast has left can't be waited on, so it is checked a few times a second
    fn listen() {
        loop {
            thread::sleep(POLL);

            let next = if hover::within("toast") {
                Self::read().shown.clone()
            } else {
                pick()
            };

            if identity(&Self::read().shown) == identity(&next) {
                continue;
            }

            let mut toast = Self::write();

            if next.is_some() {
                toast.last = next.clone();
            }

            toast.shown = next;
        }
    }
}

// a notification replaced by its sender gets a new time, so it shows again
fn identity(note: &Option<Notification>) -> Option<(u32, SystemTime)> {
    note.as_ref().map(|note| (note.id(), note.received()))
}

fn pick() -> Option<Notification> {
    let now = SystemTime::now();

    let fresh = |note: &&Notification| {
        note.urgency() == Urgency::Critical
            || now
                .duration_since(note.received())
                .map_or(true, |age| age.as_secs_f32() < timing::TOAST)
    };

    Notifications::read().list().iter().rev().find(fresh).cloned()
}

/*
 * top right, under the bar, on the grid's margin, on the output being worked
 * on. the scrim comes in from the screen's corner behind it, the same scrim
 * the surfaces use, so the text reads over any window without a box around
 * it. only the text takes clicks; the wash lets them through
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let toast = Toast::read();
    let (shown, last) = (toast.shown.clone(), toast.last.clone());
    drop(toast);

    let here = compositor::focused_output().is_none_or(|output| output == monitor.name);

    let motion = motion::presence(&format!("toast/{}", monitor.name), here && shown.is_some());

    let drawn = here && (shown.is_some() || motion.moving);

    let width = grid::span(toast::COLUMNS, monitor.width as f32);

    // the one fading out is the one that was shown
    let Some(note) = shown.or(last).filter(|_| drawn) else {
        return place(LayerWindow::new().width(1.0).height(1.0)).visible(false);
    };

    let block = content::view(&note, &theme, width, &monitor.name);

    let height = match Widget::height(&block) {
        Size::Fixed(height) => height,
        Size::Parent => 1.0,
    };

    let id = note.id();
    let key = hover::key(&monitor.name, "toast");

    let (margin, inset, fade) = (grid::MARGIN, toast::inset(), toast::fade());

    // the window runs from the screen's corner to where the wash has faded out
    let left = inset + fade;
    let window_width = left + width + margin;
    let window_height = margin + height + left;

    /*
     * a rectangle past the screen's top and right edges, blurred into a
     * shadow: dense over the text and off the edges, fading out to the left
     * and below. it comes in first and leaves last, like a surface's scrim
     */
    let wash = Rectangle::new()
        .width(inset + width + margin + fade)
        .height(fade + margin + height + inset)
        .translate(0.0, -fade)
        .shadow(
            Shadow::drop(theme.scrim)
                .opacity(SCRIM_OPACITY)
                .blur(toast::WASH),
        );

    let wash = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(amane::Padding {
            top: 0.0,
            right: 0.0,
            bottom: 0.0,
            left: fade,
        })
        .opacity(motion.scrim)
        .child(wash);

    // it comes down from above, the way it leaves too
    let card = Rectangle::new()
        .width(width)
        .height(height)
        .opacity(motion.content)
        .translate(0.0, -motion.shift)
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(move |button| match button {
            // its default action, or a dismiss when it has none
            Button::Left => Notifications::click(id),
            Button::Right | Button::Middle => Notifications::dismiss(id),
        })
        .child(block);

    let text = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(amane::Padding {
            top: margin,
            right: 0.0,
            bottom: 0.0,
            left,
        })
        .child(card);

    let clickable = InputArea {
        x: left as i32,
        y: margin as i32,
        width: width.ceil() as i32,
        height: height.ceil() as i32,
    };

    place(LayerWindow::new().width(window_width).height(window_height))
        .visible(true)
        .input_region(vec![clickable])
        .child(Stack::new(vec![Box::new(wash) as Box<dyn Widget>, Box::new(text)]))
}

// in the corner, under the bar; the text's own place on the grid is inside the window
fn place(window: LayerWindow) -> LayerWindow {
    window
        .anchor_vertical(Vertical::Top)
        .anchor_horizontal(Horizontal::Right)
        .layer(Layer::Top)
        .space(Zone::Respect)
        .namespace("yohaku-toast")
}
