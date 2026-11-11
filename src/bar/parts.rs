use std::path::PathBuf;

use amane::{
    Arc, Button, Canvas, Cap, Center, Color, End, Image, Padding, Parent, Pointer, Rectangle, Row,
    Shape, Size, Start, Text, Widget, children, shapes,
};

use crate::hover;
use crate::icons;
use crate::theme::{MONO, Theme, bar};

// the small pieces every bar group is built from

// a symbolic icon next to text, already tinted (see icons)
pub fn icon(path: PathBuf) -> Rectangle {
    Rectangle::new()
        .width(bar::ICON)
        .height(bar::ICON)
        .fill(Image::contain(path))
}

// what a value is, said after it, small and quiet: "sys", "bat"
pub fn unit(label: &str, theme: &Theme) -> Text {
    Text::new(label)
        .font(MONO)
        .size(bar::SMALL)
        .color(theme.outline)
}

/*
 * a value and its unit, "85% bat". bottom-aligned, so the small unit sits
 * on the value's line instead of floating at its middle
 */
pub fn reading(value: impl Into<String>, label: &str, theme: &Theme) -> Row {
    Row::new(children![
        Text::new(value)
            .font(MONO)
            .size(bar::TEXT)
            .color(theme.on_surface_variant),
        unit(label, theme),
    ])
    .gap(bar::ITEM_GAP)
    .align(End)
}

// a level as a ring: a track with the value over it, from the top, clockwise
pub fn ring(value: f32, theme: &Theme) -> Canvas {
    let middle = bar::RING / 2.0;

    // the stroke is centered on the radius, so half of it sits outside
    let radius = middle - bar::RING_STROKE / 2.0;

    Canvas::new().width(bar::RING).height(bar::RING).shapes(shapes![
        Arc::new()
            .center(middle, middle)
            .radius(radius)
            .stroke(bar::RING_STROKE, theme.outline_variant),
        Arc::new()
            .center(middle, middle)
            .radius(radius)
            .sweep(360.0 * value.clamp(0.0, 1.0))
            .stroke(bar::RING_STROKE, theme.primary)
            .cap(Cap::Round),
    ])
}

// an item that acts on click: pointer cursor, and its text and icon turn primary under the pointer
pub fn clickable(row: Row, key: String, action: impl Fn(Button) + 'static) -> Rectangle {
    hoverable(row, key).cursor(Pointer).on_click(action)
}

/*
 * an item that only tells the hover service when the pointer is over it, so
 * it can spell out more, like the event chip's title. the left and right
 * groups are anchored to their screen edge, so a growing item keeps the side
 * nearest the edge in place and stays under the pointer
 */
pub fn hoverable(row: Row, key: String) -> Rectangle {
    // a rectangle can't fit its child, but a row of fixed items knows its width
    let width = Widget::width(&row);

    // the bar's full height, so the pointer doesn't have to find a 16px line
    Rectangle::new()
        .width(width)
        .height(Parent)
        .align_child(Start, Center)
        .child(row)
        .on_hover(move |inside| hover::set(&key, inside))
}

// on its way from the bar's quiet text colour to primary as the pointer arrives
pub fn hovered_color(key: &str, theme: &Theme) -> Color {
    hover::mix(key, theme.on_surface_variant, theme.primary)
}

/*
 * a symbolic icon that blends between two tints as the pointer comes and
 * goes. tinting writes a copy of the svg per colour, so rather than one
 * copy per frame's colour the hovered copy fades in over the resting one
 */
pub fn hover_icon(name: &str, key: &str, rest: Color, hovered: Color) -> Option<Rectangle> {
    let amount = hover::amount(key);

    let over = (amount > 0.0)
        .then(|| icons::symbolic(name, hovered))
        .flatten();

    match over {
        Some(path) if amount >= 1.0 => Some(icon(path)),
        Some(path) => Some(icon(icons::symbolic(name, rest)?).child(icon(path).opacity(amount))),
        None => icons::symbolic(name, rest).map(icon),
    }
}

/*
 * the part of an item that unfolds on hover: it widens from nothing to its
 * own width and fades in, clipped so it never spills while it grows. `lead`
 * is the space before it, inside the clip, so the gap unfolds with it too.
 * nothing at rest, so the item is exactly as wide as before
 */
pub fn reveal(content: impl Widget + 'static, lead: f32, amount: f32) -> Option<Rectangle> {
    if amount <= 0.0 {
        return None;
    }

    let Size::Fixed(width) = content.width() else {
        return None;
    };

    let height = content.height();

    Some(
        Rectangle::new()
            .width((lead + width) * amount)
            .height(height)
            .padding(Padding {
                left: lead,
                ..Padding::default()
            })
            .align_child(Start, Center)
            .clip()
            .opacity(amount)
            .child(content),
    )
}
