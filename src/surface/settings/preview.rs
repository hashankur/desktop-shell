use std::path::PathBuf;

use amane::{Column, Image, Parent, Rectangle, Row, children};

use crate::theme::{grid, settings};

/*
 * the selected wallpaper, beside the appearance page's rows and as tall as
 * them, from the grid column the theme names. it is the one picture on the
 * surface, as the cover is on the dashboard. nothing shows until its small
 * copy is made, and nothing else moves when it appears
 */
pub fn beside(block: Rectangle, thumb: Option<PathBuf>, top: f32, height: f32, screen_width: f32) -> Row {
    let block_width = grid::span(settings::COLUMNS, screen_width);
    let start = grid::span(settings::PREVIEW_COLUMN, screen_width) + grid::GUTTER;
    let width = grid::span(settings::PREVIEW_COLUMNS, screen_width);

    let gap = Rectangle::new().width(start - block_width).height(1.0);

    let picture = match thumb {
        // the block takes its own clicks, so the surface stays open when the picture is clicked
        Some(path) => Rectangle::new()
            .width(width)
            .height(height)
            .radius(settings::PREVIEW_RADIUS)
            .on_click(|_| {})
            .fill(Image::cover(path)),
        None => Rectangle::new().width(width).height(height),
    };

    let column = Column::new(children![Rectangle::new().width(Parent).height(top), picture]).width(width);

    Row::new(children![block, gap, column])
}
