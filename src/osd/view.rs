use amane::{
    Center, Column, Horizontal, Layer, LayerWindow, Monitor, Padding, Parent, Rectangle, Row,
    Service, Shadow, SpaceBetween, Stack, Start, Text, Vertical, Widget, Zone, children,
};

use super::{Osd, Reading};
use crate::compositor;
use crate::motion;
use crate::theme::{self, MONO, Theme, grid, osd, size, toast};

/*
 * bottom right on the grid's margin, on the output being worked on: what
 * changed, small, and its level, as a number and a hairline. it sits on the
 * toast's wash, coming in from the screen's corner, so it reads over any
 * window without a box. it comes up from below and takes no clicks
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let state = Osd::read();
    let (shown, last) = (state.shown(), state.last());
    drop(state);

    let here = compositor::focused_output().is_none_or(|output| output == monitor.name);

    let motion = motion::presence(&format!("osd/{}", monitor.name), here && shown.is_some());

    let drawn = here && (shown.is_some() || motion.moving);

    // the one fading out is the one that was shown
    let Some(reading) = shown.or(last).filter(|_| drawn) else {
        return place(LayerWindow::new().width(1.0).height(1.0)).visible(false);
    };

    let width = osd::WIDTH;
    let height = height(reading);

    let (margin, inset, fade) = (grid::MARGIN, toast::inset(), toast::fade());

    // the window runs from the screen's corner to where the wash has faded out
    let reach = inset + fade;

    /*
     * a rectangle past the screen's bottom and right edges, blurred into a
     * shadow: dense over the text and off the edges, fading out to the left
     * and above
     */
    let wash = Rectangle::new()
        .width(inset + width + margin + fade)
        .height(inset + height + margin + fade)
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
            left: fade,
        })
        .opacity(motion.scrim)
        .child(wash);

    let block = Rectangle::new()
        .width(width)
        .height(height)
        .opacity(motion.content)
        .translate(0.0, motion.shift)
        .child(content(reading, &theme));

    let text = Rectangle::new()
        .width(Parent)
        .height(Parent)
        .padding(Padding {
            top: reach,
            right: 0.0,
            bottom: 0.0,
            left: reach,
        })
        .child(block);

    place(
        LayerWindow::new()
            .width(reach + width + margin)
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
        .anchor_horizontal(Horizontal::Right)
        .layer(Layer::Overlay)
        .space(Zone::Ignore)
        .namespace("yohaku-osd")
}

// what it is called, what it reads, and how full its line is; the microphone has no line
fn parts(reading: Reading) -> (&'static str, String, Option<f32>) {
    let fraction = |percent: u8| (f32::from(percent) / 100.0).clamp(0.0, 1.0);

    match reading {
        // a muted level still shows where it was, but its line is empty
        Reading::Volume { muted: true, .. } => ("volume", String::from("muted"), Some(0.0)),

        // wpctl can go past 100; the number says so, the line stops full
        Reading::Volume { percent, .. } => ("volume", percent.to_string(), Some(fraction(percent))),

        Reading::Microphone { muted } => {
            let state = if muted { "muted" } else { "on" };

            ("microphone", String::from(state), None)
        }

        Reading::Brightness { percent } => {
            ("brightness", percent.to_string(), Some(fraction(percent)))
        }
    }
}

fn line_height() -> f32 {
    size::MD * 1.5
}

fn height(reading: Reading) -> f32 {
    match parts(reading).2 {
        Some(_) => line_height() + osd::TRACK_GAP + osd::TRACK,
        None => line_height(),
    }
}

fn content(reading: Reading, theme: &Theme) -> Column {
    let (label, value, level) = parts(reading);

    let head = Row::new(children![
        Text::new(label)
            .font(MONO)
            .size(size::SM)
            .color(theme.on_surface_variant),
        Text::new(value)
            .font(MONO)
            .size(size::MD)
            .color(theme.on_surface)
    ])
    .width(osd::WIDTH)
    .justify(SpaceBetween)
    .align(Center);

    let head = Rectangle::new()
        .width(osd::WIDTH)
        .height(line_height())
        .align_child(Start, Center)
        .child(head);

    let mut lines: Vec<Box<dyn Widget>> = vec![Box::new(head)];

    if let Some(level) = level {
        let filled = Rectangle::new()
            .width(osd::WIDTH * level)
            .height(osd::TRACK)
            .fill(theme.on_surface_variant);

        lines.push(Box::new(
            Rectangle::new().width(osd::WIDTH).height(osd::TRACK_GAP),
        ));
        lines.push(Box::new(
            Rectangle::new()
                .width(osd::WIDTH)
                .height(osd::TRACK)
                .fill(theme.outline_variant)
                .child(filled),
        ));
    }

    Column::new(lines).width(osd::WIDTH)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_level_past_full_reads_true_but_fills_the_line_once() {
        let (label, value, level) = parts(Reading::Volume {
            percent: 130,
            muted: false,
        });

        assert_eq!((label, value.as_str(), level), ("volume", "130", Some(1.0)));
    }

    #[test]
    fn muted_says_so_and_empties_the_line() {
        let (_, value, level) = parts(Reading::Volume {
            percent: 60,
            muted: true,
        });

        assert_eq!((value.as_str(), level), ("muted", Some(0.0)));
        assert_eq!(parts(Reading::Microphone { muted: false }).2, None);
    }
}
