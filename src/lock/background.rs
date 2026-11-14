use amane::{Fill, Image, Parent, Rectangle, Service, Stack, Widget};

use crate::theme::{SCRIM_OPACITY, Theme, faded};
use crate::wallpaper::Wallpaper;

fn layer(fill: impl Into<Fill>) -> Box<dyn Widget> {
    Box::new(Rectangle::new().width(Parent).height(Parent).fill(fill))
}

/*
 * what the lock screen and the curtain share, so the cover that comes over
 * the desktop is the lock screen without a seam: the wallpaper under the
 * same scrim the surfaces use. without a wallpaper it is the surface color
 */
pub fn view(theme: &Theme) -> Stack {
    let path = Wallpaper::read().path().map(|path| path.to_path_buf());

    // the color stays under the picture, so a picture that can't load still leaves the lock opaque
    let mut layers = vec![layer(theme.surface)];

    if let Some(path) = path {
        layers.push(layer(Image::cover(path)));
        layers.push(layer(faded(theme.scrim, SCRIM_OPACITY)));
    }

    Stack::new(layers).width(Parent).height(Parent)
}
