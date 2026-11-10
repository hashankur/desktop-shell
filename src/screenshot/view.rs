use amane::{
    Color, Cursor, Full, Image, Keyboard, Layer, LayerWindow, Monitor, Parent, Rectangle, Service,
    Stack, Vertical, Widget, Zone,
};

use crate::theme::{self, shot};

use super::region::Area;
use super::{Screenshot, click, drag, key, leave};

/*
 * one window per output over everything, the bar included, showing that
 * output's frozen frame stretched pixel for pixel onto it. it only shows
 * once the frame is decoded, so until then the live screen is what's seen,
 * and it looks the same. the box is drawn clear, the rest dimmed
 */
pub fn view(monitor: &Monitor) -> LayerWindow {
    let theme = theme::current();

    let state = Screenshot::read();
    let frame = state.frame(&monitor.name).map(|frame| frame.path.clone());
    let keyboard = state.keyboard_output() == Some(monitor.name.as_str());
    let area = state.area_on(&monitor.name);
    drop(state);

    // asking also starts the decode; a frame that can't be read never shows
    let ready = frame.as_ref().is_some_and(Image::loaded);

    let mut layers: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(frame) = frame.filter(|_| ready) {
        let dim = theme::faded(theme.scrim, shot::DIM);

        layers.push(Box::new(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .fill(Image::stretch(frame)),
        ));
        layers.extend(dimmed(area, monitor, dim));

        if let Some(area) = area.filter(|area| area.width > 0.0 && area.height > 0.0) {
            layers.push(Box::new(outline(area, theme.primary)));
        }
    }

    let layers = Stack::new(layers).width(Parent).height(Parent);

    LayerWindow::new()
        .width(Full)
        .height(Full)
        .anchor_vertical(Vertical::Top)
        .layer(Layer::Overlay)
        .space(Zone::Ignore)
        .namespace("yohaku-screenshot")
        .visible(ready)
        .keyboard(if ready && keyboard {
            Keyboard::Exclusive
        } else {
            Keyboard::None
        })
        .on_key(key)
        .child(pointer(monitor).child(layers))
}

/*
 * the frame darkened everywhere but the box: four bands around it, or one
 * over everything before a box is drawn
 */
fn dimmed(area: Option<Area>, monitor: &Monitor, color: Color) -> Vec<Box<dyn Widget>> {
    let (width, height) = (monitor.width as f32, monitor.height as f32);

    let Some(area) = area else {
        return vec![band(0.0, 0.0, width, height, color)];
    };

    let below = area.y + area.height;
    let right = area.x + area.width;

    vec![
        band(0.0, 0.0, width, area.y, color),
        band(0.0, below, width, height - below, color),
        band(0.0, area.y, area.x, area.height, color),
        band(right, area.y, width - right, area.height, color),
    ]
}

fn band(x: f32, y: f32, width: f32, height: f32, color: Color) -> Box<dyn Widget> {
    Box::new(
        Rectangle::new()
            .width(width.max(0.0))
            .height(height.max(0.0))
            .fill(color)
            .translate(x, y),
    )
}

fn outline(area: Area, color: Color) -> Rectangle {
    Rectangle::new()
        .width(area.width)
        .height(area.height)
        .border(shot::BORDER, color)
        .translate(area.x, area.y)
}

/*
 * the whole window takes the pointer, untransformed, so a drag's points are
 * the output's own. it is the root, under the layers: amane follows a press
 * by its place among the window's targets, and the bands and outline come
 * and go mid-drag, which would move it if it sat above them. a left release
 * ends the box, a right click cancels
 */
fn pointer(monitor: &Monitor) -> Rectangle {
    let bounds = (monitor.width as f32, monitor.height as f32);

    let (on_drag, on_click, on_hover) = (
        monitor.name.clone(),
        monitor.name.clone(),
        monitor.name.clone(),
    );

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .cursor(Cursor::Crosshair)
        .on_drag(move |point| drag(&on_drag, bounds, point))
        .on_click(move |button| click(&on_click, button))
        .on_hover(move |inside| {
            if !inside {
                leave(&on_hover);
            }
        })
}
