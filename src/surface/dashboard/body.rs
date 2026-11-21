use amane::{Rectangle, Text};

use crate::theme::{SANS, Theme, dash};

/*
 * the body wrapped to the column. folded, it is cut after a few lines, with
 * a "…" where it was; open, after many more, so one long message can't
 * push the rest off the screen. says whether there was more than the folded
 * body shows, which is when there is something to open. a wrapped text with
 * no line limit can't report its height, so every height is measured
 */
pub fn body(text: &str, width: f32, open: bool, theme: &Theme) -> (Rectangle, bool) {
    let text = |lines: usize| {
        Text::new(text)
            .font(SANS)
            .size(dash::BODY)
            .color(theme.on_surface_variant)
            .wrap()
            .max_lines(lines)
    };

    let more = text(usize::MAX).height_in(width) > text(dash::BODY_LINES).height_in(width);

    let lines = if open { dash::BODY_LINES_OPEN } else { dash::BODY_LINES };

    let shown = text(lines).elide();

    let block = Rectangle::new().width(width).height(shown.height_in(width)).child(shown);

    (block, more)
}
