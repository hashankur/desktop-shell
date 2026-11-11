use amane::{Parent, Pointer, Rectangle, Row, Widget};

use crate::compositor::{self, Space};
use crate::hover;
use crate::theme::{self, Theme, bar};

/*
 * the 2px line along the bar's top edge, one segment per workspace: active
 * is the bar's accent, occupied reads as quiet text tone, empty recedes further.
 * a segment under the pointer eases toward the accent, like the bar's text
 */
pub fn view(spaces: &[Space], theme: &Theme, monitor: &str) -> Row {
    let mut segments: Vec<Box<dyn Widget>> = Vec::new();

    for space in spaces {
        let rest = if space.active {
            theme.primary
        } else if space.occupied {
            theme::faded(theme.on_surface_variant, 0.45)
        } else {
            theme::faded(theme.outline_variant, 0.6)
        };

        let key = hover::key(monitor, &format!("workspace/{}", space.index));
        let color = hover::mix(&key, rest, theme.primary);

        let target = space.clone();

        segments.push(Box::new(
            Rectangle::new()
                .width(Parent)
                .height(bar::LINE)
                .fill(color)
                .cursor(Pointer)
                .on_hover(move |inside| hover::set(&key, inside))
                .on_click(move |_| compositor::switch_to(&target)),
        ));
    }

    Row::new(segments)
        .width(Parent)
        .height(bar::LINE)
        .gap(bar::LINE_GAP)
}
