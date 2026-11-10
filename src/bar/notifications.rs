use amane::{Center, Notifications, Rectangle, Row, Service, Text, Widget};

use super::parts::{clickable, hovered_color, icon};
use crate::hover;
use crate::icons;
use crate::theme::{MONO, Theme, bar};

/*
 * the bell and how many notifications are waiting, right of the clock; a
 * click dismisses them all, until the dashboard lists them. none while
 * another daemon holds the notifications, so the bar never shows a false zero
 */
pub fn view(theme: &Theme, monitor: &str) -> Option<Rectangle> {
    let notifications = Notifications::read();
    let (running, count) = (notifications.running(), notifications.list().len());
    drop(notifications);

    if !running {
        return None;
    }

    let key = hover::key(monitor, "notifications");
    let color = hovered_color(&key, theme);

    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    if let Some(path) = icons::symbolic("preferences-system-notifications", color) {
        items.push(Box::new(icon(path)));
    }

    // waiting ones read a step brighter than the rest of the bar
    if count > 0 {
        let count_color = if hover::is(&key) {
            theme.primary
        } else {
            theme.on_surface
        };

        items.push(Box::new(
            Text::new(count.to_string())
                .font(MONO)
                .size(bar::TEXT)
                .color(count_color),
        ));
    }

    Some(clickable(
        Row::new(items).gap(bar::ITEM_GAP).align(Center),
        key,
        |_| Notifications::clear(),
    ))
}
