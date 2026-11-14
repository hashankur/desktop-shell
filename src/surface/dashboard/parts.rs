use amane::{Button, Center, Color, Image, Parent, Pointer, Rectangle, Text, Widget};

use crate::hover;
use crate::icons;
use crate::theme::{MONO, Theme, dash};

// the small pieces every dashboard column is built from

pub fn spacer(height: f32) -> Rectangle {
    Rectangle::new().width(Parent).height(height)
}

// times, ages and the like, in the small mono size
pub fn small(text: impl Into<String>, color: Color) -> Text {
    Text::new(text).font(MONO).size(dash::SMALL).color(color)
}

// a block's name, in the small capitals every label uses
pub fn label(text: &str, theme: &Theme) -> Text {
    small(text.to_uppercase(), theme.on_surface_variant)
}

// how tall a line of text in a size sits, so rows line up whatever is in them
pub fn line(size: f32) -> f32 {
    size * 1.5
}

/*
 * a symbolic icon that blends between two tints as the pointer comes and
 * goes. tinting writes a copy of the svg per colour, so rather than one
 * copy per frame's colour the hovered copy fades in over the resting one.
 * none when no theme has the icon
 */
pub fn glyph(name: &str, size: f32, key: &str, rest: Color, hovered: Color) -> Option<Rectangle> {
    let picture = |color: Color| {
        icons::symbolic(name, color).map(|path| {
            Rectangle::new()
                .width(size)
                .height(size)
                .fill(Image::contain(path))
        })
    };

    let amount = hover::amount(key);

    let over = (amount > 0.0).then(|| picture(hovered)).flatten();

    match over {
        Some(over) if amount >= 1.0 => Some(over),
        Some(over) => Some(picture(rest)?.child(over.opacity(amount))),
        None => picture(rest),
    }
}

// something that acts on click under its own hover key: the pointer cursor and nothing else
pub fn button<W: Widget + 'static>(
    child: W,
    key: String,
    action: impl Fn(Button) + 'static,
) -> Rectangle {
    let (width, height) = (Widget::width(&child), Widget::height(&child));

    Rectangle::new()
        .width(width)
        .height(height)
        .align_child(Center, Center)
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(action)
        .child(child)
}

// a symbolic icon that turns primary under the pointer and acts on click
pub fn icon_button(
    name: &str,
    size: f32,
    key: String,
    rest: Color,
    theme: &Theme,
    action: impl Fn(Button) + 'static,
) -> Option<Rectangle> {
    let glyph = glyph(name, size, &key, rest, theme.primary)?;

    Some(button(glyph, key, action))
}

// small text that turns primary under the pointer and acts on click
pub fn text_button(
    text: &str,
    key: String,
    theme: &Theme,
    action: impl Fn(Button) + 'static,
) -> Rectangle {
    let color = hover::mix(&key, theme.on_surface_variant, theme.primary);

    button(small(text, color), key, action)
}
