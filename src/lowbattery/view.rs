use amane::{
    Column, Horizontal, Layer, LayerWindow, Monitor, Padding, Parent, Rectangle, Service, Shadow,
    Size, Stack, Text, Vertical, Widget, Zone,
};

use super::{Alert, Level, LowBattery};
use crate::charge::{self, Charge};
use crate::compositor;
use crate::motion;
use crate::theme::{self, MONO, SANS, Theme, grid, low_battery, size, space, toast};

/*
 * bottom left on the grid's margin, on the output being worked on: that the
 * battery is low, small, then how much is left and for how long. it sits on
 * the toast's wash, coming in from the screen's corner, so it reads over any
 * window without a box. it comes up from below and takes no clicks
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let state = LowBattery::read();
    let (shown, last) = (state.shown(), state.last());
    drop(state);

    let here = compositor::focused_output().is_none_or(|output| output == monitor.name);

    let motion = motion::presence(&format!("low-battery/{}", monitor.name), here && shown.is_some());

    let drawn = here && (shown.is_some() || motion.moving);

    // the one fading out is the one that was shown
    let Some(alert) = shown.or(last).filter(|_| drawn) else {
        return place(LayerWindow::new().width(1.0).height(1.0)).visible(false);
    };

    let width = low_battery::WIDTH;
    let content = content(alert, &theme);

    let height = match Widget::height(&content) {
        Size::Fixed(height) => height,
        Size::Parent => 1.0,
    };

    let (margin, inset, fade) = (grid::MARGIN, toast::inset(), toast::fade());

    // the window runs from the screen's corner to where the wash has faded out
    let reach = inset + fade;

    /*
     * a rectangle past the screen's bottom and left edges, blurred into a
     * shadow: dense over the text and off the edges, fading out to the right
     * and above
     */
    let wash = Rectangle::new()
        .width(inset + width + margin + fade)
        .height(inset + height + margin + fade)
        .translate(-fade, 0.0)
        .shadow(
            Shadow::drop(theme.scrim)
                .opacity(toast::SCRIM_OPACITY)
                .blur(toast::WASH),
        );

    let wash = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(Padding {
            top: fade,
            right: 0.0,
            bottom: 0.0,
            left: 0.0,
        })
        .opacity(motion.scrim)
        .child(wash);

    let block = Rectangle::new()
        .width(width)
        .height(height)
        .opacity(motion.content)
        .translate(0.0, motion.shift)
        .child(content);

    let text = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(Padding {
            top: reach,
            right: 0.0,
            bottom: 0.0,
            left: margin,
        })
        .child(block);

    place(
        LayerWindow::new()
            .width(margin + width + reach)
            .height(reach + height + margin),
    )
    .visible(true)
    .click_through()
    .child(Stack::new(vec![
        Box::new(wash) as Box<dyn Widget>,
        Box::new(text),
    ]))
}

// over everything, so a full-screen window or an open surface doesn't hide it
fn place(window: LayerWindow) -> LayerWindow {
    window
        .anchor_vertical(Vertical::Bottom)
        .anchor_horizontal(Horizontal::Left)
        .layer(Layer::Overlay)
        .space(Zone::Ignore)
        .namespace("yohaku-low-battery")
}

// the word for how bad it is, and the line under it: the charge, and how long it will last
fn parts(alert: Alert) -> (&'static str, String) {
    let word = match alert.level {
        Level::Low => "battery low",
        Level::Critical => "battery critical",
    };

    (word, format!("{}%", alert.percent))
}

fn content(alert: Alert, theme: &Theme) -> Column {
    let (word, charge) = parts(alert);

    // a critical one says so in the accent, like a critical toast
    let accent = match alert.level {
        Level::Low => theme.on_surface_variant,
        Level::Critical => theme.error,
    };

    // read only while it shows, so its estimate doesn't redraw anything the rest of the time
    let left = Charge::read()
        .remaining()
        .filter(|remaining| !remaining.charging)
        .map(|remaining| format!("{} left", charge::duration(remaining.minutes)));

    let line = match left {
        Some(left) => format!("{charge} · {left}"),
        None => charge,
    };

    let head = Text::new(word)
        .font(MONO)
        .size(size::SM)
        .weight(toast::WEIGHT)
        .color(accent);

    let line = Text::new(line)
        .font(SANS)
        .size(size::MD)
        .weight(toast::SUMMARY_WEIGHT)
        .color(theme.on_surface);

    Column::new(vec![Box::new(head) as Box<dyn Widget>, Box::new(line)])
        .width(low_battery::WIDTH)
        .gap(space::SM / 2.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn says_how_bad_it_is_and_the_charge() {
        let low = parts(Alert { level: Level::Low, percent: 14 });
        let critical = parts(Alert { level: Level::Critical, percent: 4 });

        assert_eq!((low.0, low.1.as_str()), ("battery low", "14%"));
        assert_eq!((critical.0, critical.1.as_str()), ("battery critical", "4%"));
    }
}
