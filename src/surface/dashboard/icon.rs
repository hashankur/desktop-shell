use std::path::{Path, PathBuf};

use amane::{Apps, Color, Service};

use crate::icons;

/*
 * the notification's own picture if it sent one, like an avatar, then its
 * icon if that's a file, then the icon of the app it names or comes from.
 * a system one names a theme icon instead, like "battery-low", which has
 * no app, so last comes the symbolic icon, tinted like the text beside it
 */
pub fn icon(image: &str, name: &str, app: &str, tint: Color) -> Option<PathBuf> {
    full_color(image, name, app).or_else(|| {
        let (name, app) = (name.trim(), app.trim());

        (!name.is_empty())
            .then(|| icons::symbolic(name, tint))
            .flatten()
            .or_else(|| icons::app(app, tint))
    })
}

fn full_color(image: &str, icon: &str, app: &str) -> Option<PathBuf> {
    let file = |text: &str| {
        let path = text.trim().strip_prefix("file://").unwrap_or(text.trim());

        path.starts_with('/').then(|| PathBuf::from(path))
    };

    if let Some(path) = file(image).or_else(|| file(icon)) {
        return Some(path);
    }

    let (name, app) = (icon.trim(), app.trim());

    let matches = |text: &str, wanted: &str| !wanted.is_empty() && text.eq_ignore_ascii_case(wanted);

    Apps::read()
        .list()
        .iter()
        .find(|entry| {
            let own = entry.icon().unwrap_or_default();

            matches(own, name) || matches(own, app) || matches(entry.name(), app)
        })
        .and_then(|entry| entry.icon_path())
        .map(Path::to_path_buf)
}
