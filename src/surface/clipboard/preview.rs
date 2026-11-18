use amane::{Column, Image, Parent, Rectangle, Text, Widget};

use super::decode::{Body, Preview};
use super::kind::Kind;
use super::parse::Clip;
use crate::surface::list::{Beside, list_height};
use crate::theme::{MONO, SANS, Theme, clipboard, grid, size, space};

/*
 * the selected clip beside the list, as the wallpaper sits beside settings'
 * rows: what it is on the group label's line, then the picture whole or the
 * text as far as it fits. nothing shows until the clip is read, and nothing
 * else moves when it is. a hidden clip says so and shows nothing more
 */
pub fn beside(
    theme: &Theme,
    clip: Option<&Clip>,
    preview: Option<&Preview>,
    revealed: bool,
    screen_width: f32,
) -> Option<Beside> {
    let clip = clip?;

    let hidden = clip.kind == Kind::Secret && !revealed;

    let preview = preview.filter(|preview| preview.id == clip.id);

    let items: Vec<Box<dyn Widget>> = match (hidden, preview) {
        (true, _) => vec![Box::new(label("hidden · looks like a password", theme))],

        (false, Some(preview)) => {
            let width = grid::span(clipboard::PREVIEW_COLUMNS, screen_width);
            let height = list_height() - size::SM * 1.5 - space::SM;

            match body(clip, &preview.body, theme, width, height) {
                Some((meta, content)) => vec![
                    Box::new(label(&meta, theme)),
                    Box::new(Rectangle::new().width(Parent).height(space::SM)),
                    content,
                ],
                None => Vec::new(),
            }
        }

        (false, None) => Vec::new(),
    };

    // the block takes its own clicks, so the surface stays open when the preview is clicked
    let content = Rectangle::new()
        .width(Parent)
        .height(list_height())
        .on_click(|_| {})
        .clip()
        .child(Column::new(items).width(Parent));

    Some(Beside {
        column: clipboard::PREVIEW_COLUMN,
        columns: clipboard::PREVIEW_COLUMNS,
        content,
    })
}

fn label(text: &str, theme: &Theme) -> Text {
    Text::new(text.to_uppercase())
        .font(MONO)
        .size(size::SM)
        .color(theme.on_surface_variant)
}

// the meta line and what goes under it, or none for a clip there is nothing to show of
fn body(clip: &Clip, body: &Body, theme: &Theme, width: f32, height: f32) -> Option<(String, Box<dyn Widget>)> {
    match body {
        Body::Image(path) => {
            let Kind::Image { format, size, weight } = &clip.kind else {
                return None;
            };

            let (shown_width, shown_height) = fit(size, width, height);

            let picture = Rectangle::new()
                .width(shown_width)
                .height(shown_height)
                .fill(Image::contain(path).thumbnail(shown_width as u32, shown_height as u32));

            Some((format!("image · {format} · {size} · {weight}"), Box::new(picture)))
        }

        Body::Text {
            text,
            chars,
            lines,
            cut,
            code,
        } => {
            let font = if *code { MONO } else { SANS };

            let shown = Text::new(text.clone())
                .font(font)
                .size(size::MD)
                .color(theme.on_surface)
                .wrap()
                .elide()
                .max_lines(fitting(font, width, height));

            let more = if *cut { "+" } else { "" };

            let meta = format!(
                "{} · {chars}{more} {} · {lines}{more} {}",
                kind_word(&clip.kind),
                plural(*chars, "character"),
                plural(*lines, "line"),
            );

            Some((meta, Box::new(shown)))
        }

        Body::Nothing => match &clip.kind {
            Kind::Image { format, size, weight } => Some((
                format!("image · {format} · {size} · {weight} · no preview"),
                Box::new(Rectangle::new().width(Parent).height(1.0)),
            )),
            _ => None,
        },
    }
}

/*
 * the picture's own size, shrunk to fit the space but never grown, so a
 * small one stays sharp and sits under the meta line instead of floating in
 * the middle, as amane's contain would place it. "1606×926" comes from
 * cliphist; a size it didn't give fills the space
 */
fn fit(size: &str, width: f32, height: f32) -> (f32, f32) {
    let parsed = size
        .split_once('×')
        .and_then(|(across, down)| Some((across.parse::<f32>().ok()?, down.parse::<f32>().ok()?)))
        .filter(|(across, down)| *across > 0.0 && *down > 0.0);

    let Some((across, down)) = parsed else {
        return (width, height);
    };

    let scale = (width / across).min(height / down).min(1.0);

    ((across * scale).floor().max(1.0), (down * scale).floor().max(1.0))
}

fn kind_word(kind: &Kind) -> &'static str {
    match kind {
        Kind::Link(_) => "link",
        Kind::Path => "path",
        Kind::Secret => "shown · looks like a password",
        Kind::Text | Kind::Image { .. } => "text",
    }
}

fn plural(count: usize, word: &str) -> String {
    if count == 1 {
        word.to_string()
    } else {
        format!("{word}s")
    }
}

// how many lines of the preview's text fit in its height, measured from the face itself
fn fitting(font: &str, width: f32, height: f32) -> usize {
    let line = |text: &str| Text::new(text).font(font).size(size::MD).wrap().height_in(width);

    let one = line("a");
    let step = line("a\na") - one;

    if step <= 0.0 || height < one {
        return 1;
    }

    1 + ((height - one) / step).floor() as usize
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_small_picture_keeps_its_size() {
        assert_eq!(fit("188×75", 576.0, 277.0), (188.0, 75.0));
    }

    #[test]
    fn a_large_picture_shrinks_to_fit_either_way() {
        assert_eq!(fit("1606×926", 576.0, 277.0), (480.0, 277.0));
        assert_eq!(fit("2000×100", 576.0, 277.0), (576.0, 28.0));
    }

    #[test]
    fn a_size_that_cannot_be_read_fills_the_space() {
        assert_eq!(fit("big", 576.0, 277.0), (576.0, 277.0));
        assert_eq!(fit("0×10", 576.0, 277.0), (576.0, 277.0));
    }
}
