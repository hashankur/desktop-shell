use amane::{Center, Notifications, Rectangle, Row, Service, Text, Widget};

use super::parts::{clickable, hover_icon};
use crate::history;
use crate::hover;
use crate::surface::{Kind, Surface};
use crate::toast::Quiet;
use crate::theme::{MONO, Theme, bar};

/*
 * the bell and how many notifications are waiting, in the bar's right corner; a
 * click opens the dashboard, which lists them and clears them. none while
 * another daemon holds the notifications, so the bar never shows a false zero
 */
pub fn view(theme: &Theme, monitor: &str) -> Option<Rectangle> {
    let notifications = Notifications::read();
    let (running, live) = (notifications.running(), notifications.list().len());
    drop(notifications);

    // the ones kept from an earlier run wait too
    let count = live + history::restored_count();

    if !running {
        return None;
    }

    let key = hover::key(monitor, "notifications");
    let mut items: Vec<Box<dyn Widget>> = Vec::new();

    // do not disturb crosses the bell out, so toasts held back are never a surprise
    let bell = if Quiet::read().on() {
        "notifications-disabled"
    } else {
        "preferences-system-notifications"
    };

    if let Some(icon) = hover_icon(bell, &key, theme.on_surface_variant, theme.primary) {
        items.push(Box::new(icon));
    }

    // waiting ones read a step brighter than the rest of the bar
    if count > 0 {
        let count_color = hover::mix(&key, theme.on_surface, theme.primary);

        items.push(Box::new(
            Text::new(count.to_string())
                .font(MONO)
                .size(bar::TEXT)
                .weight(bar::TEXT_WEIGHT)
                .color(count_color),
        ));
    }

    Some(clickable(
        Row::new(items).gap(bar::ITEM_GAP).align(Center),
        key,
        |_| Surface::toggle(Kind::Dashboard),
    ))
}
