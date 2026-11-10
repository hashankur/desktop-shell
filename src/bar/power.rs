use amane::{Battery, Center, Rectangle, Row, Service, Text, Widget, children};

use super::parts::{clickable, hovered_color, icon, tag};
use crate::hover;
use crate::icons;
use crate::surface::{Kind, Surface};
use crate::theme::{MONO, Theme, bar};

// PWR, the battery's segments and percent when there is one, then the power icon
pub fn view(theme: &Theme, monitor: &str) -> Row {
    let mut items: Vec<Box<dyn Widget>> = vec![Box::new(tag("PWR", theme))];

    let battery = Battery::read();
    let (present, percent) = (battery.present(), battery.percent());
    drop(battery);

    if present {
        let level = Row::new(children![
            segments(percent, theme),
            Text::new(format!("{percent}%"))
                .font(MONO)
                .size(bar::TEXT)
                .color(theme.on_surface_variant),
        ])
        .gap(bar::ITEM_GAP)
        .align(Center);

        items.push(Box::new(level));
    }

    // the power icon opens the power surface; it turns primary under the pointer like the rest
    let key = hover::key(monitor, "power");
    let color = hovered_color(&key, theme);

    if let Some(path) = icons::symbolic("system-shutdown", color) {
        items.push(Box::new(clickable(
            Row::new(children![icon(path)]),
            key,
            |_| Surface::toggle(Kind::Power),
        )));
    }

    Row::new(items).gap(bar::GROUP_GAP).align(Center)
}

// a row of cells, lit in proportion to the charge
fn segments(percent: u8, theme: &Theme) -> Row {
    let count = bar::BATTERY_SEGMENTS;

    let lit = (usize::from(percent.min(100)) * count + 50) / 100;

    let width = (bar::BATTERY_WIDTH - bar::BATTERY_GAP * (count - 1) as f32) / count as f32;

    let cells: Vec<Box<dyn Widget>> = (0..count)
        .map(|index| {
            let fill = if index < lit {
                theme.primary
            } else {
                theme.surface_container_high
            };

            Box::new(
                Rectangle::new()
                    .width(width)
                    .height(bar::BATTERY_HEIGHT)
                    .fill(fill),
            ) as Box<dyn Widget>
        })
        .collect();

    Row::new(cells).gap(bar::BATTERY_GAP)
}
